import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { DeliveryEntity } from './delivery.entity';
import { DeliveryItemEntity } from './delivery-item.entity';
import { InvoiceEntity } from '../invoices/invoice.entity';
import { InvoiceItemEntity } from '../invoices/invoice-item.entity';
import { ProductEntity } from '../products/product.entity';

@Injectable()
export class DeliveriesService {
  constructor(
    @InjectRepository(DeliveryEntity) private readonly delRepo: Repository<DeliveryEntity>,
    @InjectRepository(DeliveryItemEntity) private readonly delItemRepo: Repository<DeliveryItemEntity>,
    @InjectRepository(InvoiceEntity) private readonly invRepo: Repository<InvoiceEntity>,
    @InjectRepository(InvoiceItemEntity) private readonly invItemRepo: Repository<InvoiceItemEntity>,
    @InjectRepository(ProductEntity) private readonly prodRepo: Repository<ProductEntity>,
  ) {}

  async nextDeliveryNo() {
    const count = await this.delRepo.count();
    return `DEL-${String(count + 1).padStart(6, '0')}`;
  }

  /**
   * Create PACKED delivery from APPROVED invoice
   * Stock will NOT change here.
   */
  async createFromInvoice(input: { invoice_id: number; warehouse_id?: number | null }) {
    const inv = await this.invRepo.findOne({ where: { id: input.invoice_id } });
    if (!inv) throw new NotFoundException('Invoice not found');

    if (inv.status !== 'APPROVED') {
      throw new BadRequestException('Only APPROVED invoice can be packed for delivery');
    }

    // prevent duplicate delivery per invoice (simple rule)
    const existing = await this.delRepo.findOne({ where: { invoice_id: inv.id } });
    if (existing) {
      return { ok: true, delivery: existing, message: 'Delivery already exists for this invoice' };
    }

    const items = await this.invItemRepo.find({ where: { invoice_id: inv.id } });
    if (!items.length) throw new BadRequestException('Invoice has no items');

    const delivery_no = await this.nextDeliveryNo();
    const d = this.delRepo.create({
      delivery_no,
      invoice_id: inv.id,
      warehouse_id: input.warehouse_id ?? null,
      status: 'PACKED',
      packed_at: new Date(),
    });

    const saved = await this.delRepo.save(d);

    // copy items (qty + free_qty) => total qty
    const dItems = items.map((it) => {
      const total = Number(it.qty) + Number(it.free_qty || 0);
      return this.delItemRepo.create({
        delivery_id: saved.id,
        product_id: it.product_id,
        qty: Number(total.toFixed(2)) as any,
      });
    });

    await this.delItemRepo.save(dItems);

    return { ok: true, delivery: saved, items: dItems };
  }

  async dispatch(id: number) {
    const d = await this.delRepo.findOne({ where: { id } });
    if (!d) throw new NotFoundException('Delivery not found');

    if (d.status === 'DELIVERED') throw new BadRequestException('Already delivered');
    if (d.status === 'DISPATCHED') return { ok: true, delivery: d, message: 'Already dispatched' };

    d.status = 'DISPATCHED';
    d.dispatched_at = new Date();
    await this.delRepo.save(d);

    return { ok: true, delivery: d };
  }

  /**
   * Confirm delivered => STOCK OUT happens here
   */
  async confirmDelivered(id: number, confirmed_by: number) {
    const d = await this.delRepo.findOne({ where: { id } });
    if (!d) throw new NotFoundException('Delivery not found');

    if (d.status === 'DELIVERED') {
      return { ok: true, delivery: d, message: 'Already delivered (no double stock out)' };
    }

    if (d.status !== 'DISPATCHED' && d.status !== 'PACKED') {
      throw new BadRequestException('Invalid delivery status');
    }

    const items = await this.delItemRepo.find({ where: { delivery_id: d.id } });
    if (!items.length) throw new BadRequestException('Delivery has no items');

    // STOCK OUT now
    for (const it of items) {
      const p = await this.prodRepo.findOne({ where: { id: it.product_id } });
      if (!p) continue;

      const next = Number(p.in_stock) - Number(it.qty);
      p.in_stock = (next < 0 ? 0 : Number(next.toFixed(2))) as any;
      await this.prodRepo.save(p);
    }

    d.status = 'DELIVERED';
    d.delivered_at = new Date();
    d.confirmed_by = confirmed_by;
    await this.delRepo.save(d);

    return { ok: true, delivery: d, message: 'Delivered confirmed & stock reduced' };
  }

  async getOne(id: number) {
    const d = await this.delRepo.findOne({ where: { id } });
    if (!d) throw new NotFoundException('Delivery not found');
    const items = await this.delItemRepo.find({ where: { delivery_id: d.id } });
    return { ok: true, delivery: d, items };
  }

  async list(status?: string) {
    const where: any = {};
    if (status) where.status = status;
    return this.delRepo.find({ where, order: { id: 'DESC' as any } });
  }
}