import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { In, Repository } from 'typeorm';
import { InvoiceEntity } from './invoice.entity';
import { InvoiceItemEntity } from './invoice-item.entity';
import { ApprovalEntity } from '../approvals/approval.entity';
import { Role } from '../auth/roles.enum';
import { AuditAction, AuditLogEntity } from '../sync/audit-log.entity';
import * as fs from 'fs';
import * as path from 'path';
import PDFDocument = require('pdfkit');

@Injectable()
export class InvoicesService {
  constructor(
    @InjectRepository(InvoiceEntity) private readonly invRepo: Repository<InvoiceEntity>,
    @InjectRepository(InvoiceItemEntity) private readonly itemRepo: Repository<InvoiceItemEntity>,
    @InjectRepository(ApprovalEntity) private readonly approvalRepo: Repository<ApprovalEntity>,
    @InjectRepository(AuditLogEntity) private readonly auditRepo: Repository<AuditLogEntity>,
  ) {}

  async nextInvoiceNo() {
    const count = await this.invRepo.count();
    const n = count + 1;
    return `INV-${String(n).padStart(6, '0')}`;
  }

  async createDraft(
    user: { sub: number; role: Role },
    scope: { territoryIds: number[] | null },
    input: {
      territory_id?: number;
      party_id: number;
      invoice_date: string;
      invoice_time: string;
      discount_percent?: number;
      discount_amount?: number;
      remarks?: string | null;
    },
  ) {
    const territoryIds = scope?.territoryIds ?? [];
    let territoryId = input.territory_id;

    if (user.role === Role.MPO) {
      if (!territoryIds.length) {
        throw new BadRequestException(
          'No territory assigned to your user. Please contact admin.',
        );
      }
      territoryId = territoryIds[0];
    }

    if (!territoryId) {
      throw new BadRequestException('territory_id is required');
    }

    if (
      user.role !== Role.SUPER_ADMIN &&
      !territoryIds.includes(Number(territoryId))
    ) {
      throw new BadRequestException(
        'You are not allowed to create invoice in this territory',
      );
    }

    const invoice_no = await this.nextInvoiceNo();

    const inv = this.invRepo.create({
      invoice_no,
      mpo_user_id: user.sub,
      territory_id: Number(territoryId),
      party_id: input.party_id,
      invoice_date: input.invoice_date,
      invoice_time: input.invoice_time,
      status: 'DRAFT',
      subtotal: 0,
      discount_percent: Number(input.discount_percent ?? 0),
      discount_amount: Number(input.discount_amount ?? 0),
      net_total: 0,
      received_amount: 0,
      due_amount: 0,
      remarks: input.remarks ?? null,
      version: 1,
    });

    return this.invRepo.save(inv);
  }

  async addItems(
    invoice_id: number,
    items: Array<{ product_id: number; qty: number; free_qty?: number; unit_price: number }>,
    user: { sub: number; role: Role },
    scope: { territoryIds: number[] | null },
  ) {
    const inv = await this.findScopedInvoiceOrFail(invoice_id, user, scope);
    if (inv.status !== 'DRAFT') {
      throw new BadRequestException('Only DRAFT invoice can be edited');
    }

    await this.itemRepo.delete({ invoice_id });

    const rows = items.map((it) => {
      const qty = Number(it.qty);
      const unit_price = Number(it.unit_price);
      const line_total = qty * unit_price;

      return this.itemRepo.create({
        invoice_id,
        product_id: Number(it.product_id),
        qty,
        free_qty: Number(it.free_qty ?? 0),
        unit_price,
        line_total,
      });
    });

    await this.itemRepo.save(rows);

    const subtotal = rows.reduce((s, r) => s + Number(r.line_total), 0);
    const discAmt = Number(inv.discount_amount ?? 0);
    const discPct = Number(inv.discount_percent ?? 0);

    const discountFromPct = discPct > 0 ? (subtotal * discPct) / 100 : 0;
    const discount = discAmt > 0 ? discAmt : discountFromPct;

    const net = subtotal - discount;
    inv.subtotal = Number(subtotal.toFixed(2)) as any;
    inv.net_total = Number(net.toFixed(2)) as any;
    inv.due_amount = Number(net.toFixed(2)) as any;
    inv.version = Number(inv.version || 1) + 1;

    await this.invRepo.save(inv);

    return { ok: true, invoice: inv, items: rows };
  }

  async submit(
    id: number,
    user: { sub: number; role: Role },
    scope: { territoryIds: number[] | null },
  ) {
    const invoice = await this.findScopedInvoiceOrFail(id, user, scope);

    if (invoice.status !== 'DRAFT') {
      throw new BadRequestException('Already submitted or processed');
    }

    invoice.status = 'PENDING_APPROVAL';
    invoice.version = Number(invoice.version || 1) + 1;
    await this.invRepo.save(invoice);

    await this.approvalRepo.save(
      this.approvalRepo.create({
        entity_type: 'INVOICE',
        entity_id: invoice.id,
        status: 'PENDING',
        requested_by: user.sub,
        requested_at: new Date(),
      }),
    );

    return { ok: true, message: 'Invoice submitted for approval' };
  }

  async cancel(
    id: number,
    user: { sub: number; role: Role },
    scope: { territoryIds: number[] | null },
  ) {
    const invoice = await this.findScopedInvoiceOrFail(id, user, scope);

    if (!['DRAFT', 'DECLINED', 'PENDING_APPROVAL'].includes(String(invoice.status))) {
      throw new BadRequestException('Invoice cannot be cancelled');
    }

    invoice.status = 'CANCELLED';
    invoice.version = Number(invoice.version || 1) + 1;
    await this.invRepo.save(invoice);

    return { ok: true, invoice };
  }

  async markApproved(
    id: number,
    user: { sub: number; role: Role },
    scope: { territoryIds: number[] | null },
  ) {
    const invoice = await this.findScopedInvoiceOrFail(id, user, scope, true);

    if (String(invoice.status) !== 'PENDING_APPROVAL') {
      throw new BadRequestException('Invoice is not pending approval');
    }

    const before = { ...invoice };

    invoice.status = 'APPROVED';
    invoice.version = Number(invoice.version || 1) + 1;
    await this.invRepo.save(invoice);

    await this.writeAudit('INVOICE', invoice.id, 'APPROVE', user, before, invoice);

    return invoice;
  }

  async markDeclined(
    id: number,
    user: { sub: number; role: Role },
    scope: { territoryIds: number[] | null },
    reason: string,
  ) {
    const invoice = await this.findScopedInvoiceOrFail(id, user, scope, true);

    if (String(invoice.status) !== 'PENDING_APPROVAL') {
      throw new BadRequestException('Invoice is not pending approval');
    }

    const before = { ...invoice };

    invoice.status = 'DECLINED';
    invoice.remarks = reason || invoice.remarks || null;
    invoice.version = Number(invoice.version || 1) + 1;
    await this.invRepo.save(invoice);

    await this.writeAudit('INVOICE', invoice.id, 'DECLINE', user, before, invoice);

    return invoice;
  }

  private async findScopedInvoiceOrFail(
    id: number,
    user: { sub: number; role: Role },
    scope: { territoryIds: number[] | null },
    _forApproval = false,
  ) {
    const invoice = await this.invRepo.findOne({ where: { id } });
    if (!invoice) throw new NotFoundException('Invoice not found');

    if (user.role === Role.SUPER_ADMIN) return invoice;

    const territoryIds = scope?.territoryIds ?? [];

    if (user.role === Role.MPO) {
      if (Number(invoice.mpo_user_id) !== user.sub) {
        throw new BadRequestException('Unauthorized access to this invoice');
      }
      return invoice;
    }

    if (!territoryIds.includes(Number(invoice.territory_id))) {
      throw new BadRequestException('Invoice out of territory scope');
    }

    return invoice;
  }

  private async writeAudit(
    entityType: string,
    entityId: number,
    action: AuditAction,
    user: { sub: number; role: Role },
    before: any,
    after: any,
  ) {
    await this.auditRepo.save(
      this.auditRepo.create({
        entity_type: entityType,
        entity_uuid: (after as any).uuid || null,
        entity_id: entityId,
        action: action,
        actor_user_id: user.sub,
        actor_role: user.role,
        before_json: before,
        after_json: after,
      }),
    );
  }

  async generatePdf(
    invoice_id: number,
    user: { sub: number; role: Role },
    scope: { territoryIds: number[] | null },
  ) {
    const inv = await this.findScopedInvoiceOrFail(invoice_id, user, scope);

    const items = await this.itemRepo.find({ where: { invoice_id } });

    const fileName = `${inv.invoice_no}.pdf`;
    const outDir = path.join(process.cwd(), 'storage', 'invoices');
    const outPath = path.join(outDir, fileName);

    if (!fs.existsSync(outDir)) fs.mkdirSync(outDir, { recursive: true });

    const doc = new PDFDocument({ size: 'A4', margin: 40 });
    const stream = fs.createWriteStream(outPath);
    doc.pipe(stream);

    doc.fontSize(18).text('JBCL ERP - Invoice', { align: 'center' });
    doc.moveDown(0.5);
    doc.fontSize(12).text(`Invoice No: ${inv.invoice_no}`);
    doc.text(`Date: ${inv.invoice_date}  Time: ${inv.invoice_time}`);
    doc.text(`Party ID: ${inv.party_id}  Territory ID: ${inv.territory_id}`);
    doc.moveDown();

    doc.fontSize(12).text('Items:', { underline: true });
    doc.moveDown(0.5);

    doc.fontSize(10);
    items.forEach((it, idx) => {
      doc.text(
        `${idx + 1}. product_id=${it.product_id} | qty=${it.qty} | unit_price=${it.unit_price} | total=${it.line_total}`,
      );
    });

    doc.moveDown();
    doc.fontSize(12).text(`Subtotal: ${inv.subtotal}`);
    doc.text(`Discount: ${Number(inv.discount_amount) || 0}`);
    doc.text(`Net Total: ${inv.net_total}`);
    doc.text(`Due: ${inv.due_amount}`);

    doc.end();

    await new Promise<void>((resolve, reject) => {
      stream.on('finish', () => resolve());
      stream.on('error', (e) => reject(e));
    });

    const pdf_url = `/files/invoices/${fileName}`;
    (inv as any).pdf_url = pdf_url;
    await this.invRepo.save(inv);

    return { ok: true, pdf_url };
  }

  async list(
    user: { sub: number; role: Role },
    scope: { territoryIds: number[] | null },
    status?: string,
    party_id?: number,
  ) {
    const qb = this.invRepo
      .createQueryBuilder('invoice')
      .leftJoinAndSelect('invoice.party', 'party')
      .orderBy('invoice.id', 'DESC');

    if (status) {
      qb.andWhere('invoice.status = :status', { status });
    }

    if (party_id !== undefined) {
      qb.andWhere('invoice.party_id = :party_id', { party_id });
    }

    if (user.role === Role.SUPER_ADMIN) {
      return await qb.getMany();
    }

    if (user.role === Role.MPO) {
      qb.andWhere('invoice.mpo_user_id = :userId', { userId: user.sub });
      return await qb.getMany();
    }

    const territoryIds = scope?.territoryIds ?? [];
    if (!territoryIds.length) return [];

    qb.andWhere('invoice.territory_id IN (:...territoryIds)', { territoryIds });
    return await qb.getMany();
  }
}