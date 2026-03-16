import { BadRequestException, Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { MonthlyTargetEntity } from './monthly-target.entity';
import { InvoiceEntity } from '../invoices/invoice.entity';
import { CollectionEntity } from '../collections/collection.entity';

@Injectable()
export class TargetsService {
  constructor(
    @InjectRepository(MonthlyTargetEntity) private readonly repo: Repository<MonthlyTargetEntity>,
    @InjectRepository(InvoiceEntity) private readonly invRepo: Repository<InvoiceEntity>,
    @InjectRepository(CollectionEntity) private readonly colRepo: Repository<CollectionEntity>,
  ) {}

  async upsertTarget(input: {
    user_id: number;
    territory_id?: number | null;
    year: number;
    month: number;
    sales_target: number;
    collection_target: number;
    set_by: number;
  }) {
    if (input.month < 1 || input.month > 12) throw new BadRequestException('month must be 1-12');

    const where: any = {
      user_id: input.user_id,
      territory_id: input.territory_id ?? null,
      year: input.year,
      month: input.month,
    };

    const exist = await this.repo.findOne({ where });
    if (exist) {
      exist.sales_target = Number(input.sales_target) as any;
      exist.collection_target = Number(input.collection_target) as any;
      exist.set_by = input.set_by;
      return this.repo.save(exist);
    }

    const row = this.repo.create({
      ...where,
      sales_target: Number(input.sales_target),
      collection_target: Number(input.collection_target),
      set_by: input.set_by,
    });

    return this.repo.save(row);
  }

  getTarget(user_id: number, year: number, month: number) {
    return this.repo.find({ where: { user_id, year, month }, order: { id: 'DESC' as any } });
  }

  async dashboard(user_id: number, year: number, month: number) {
    // simple month range: YYYY-MM-01 to YYYY-MM-31 (rough)
    const m = String(month).padStart(2, '0');
    const from = `${year}-${m}-01`;
    const to = `${year}-${m}-31`;

    const [targets] = await Promise.all([
      this.repo.findOne({ where: { user_id, year, month } }),
    ]);

    // invoices total (APPROVED only to be safe)
    const invs = await this.invRepo.find({ where: { mpo_user_id: user_id } as any });
    const monthInvTotal = invs
      .filter((i) => i.invoice_date >= from && i.invoice_date <= to)
      .reduce((s, i) => s + Number(i.net_total), 0);

    // collections total (APPROVED only)
    const cols = await this.colRepo.find({ where: { mpo_user_id: user_id } as any });
    const monthColTotal = cols
      .filter((c) => c.collection_date >= from && c.collection_date <= to)
      .reduce((s, c) => s + Number(c.amount), 0);

    return {
      ok: true,
      year,
      month,
      target: {
        sales_target: Number(targets?.sales_target ?? 0),
        collection_target: Number(targets?.collection_target ?? 0),
      },
      actual: {
        sales: Number(monthInvTotal.toFixed(2)),
        collection: Number(monthColTotal.toFixed(2)),
      },
    };
  }
}