import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { ObjectLiteral, Repository, SelectQueryBuilder } from 'typeorm';
import { Role } from '../auth/roles.enum';
import { InvoiceEntity } from '../invoices/invoice.entity';
import { CollectionEntity } from '../collections/collection.entity';
import { ExpenseEntity } from '../expenses/expense.entity';
import {
  AccountingVoucherEntity,
  AccountingVoucherStatus,
  AccountingVoucherType,
} from './accounting-voucher.entity';

type AuthUser = {
  sub?: number;
  id?: number;
  role?: Role | string;
};

type UserScope = {
  territoryIds?: number[] | null;
};

type Filters = {
  from?: string;
  to?: string;
  territory_id?: number;
  party_id?: number;
  user_id?: number;
  status?: string;
};

@Injectable()
export class AccountingService {
  constructor(
    @InjectRepository(InvoiceEntity)
    private readonly invRepo: Repository<InvoiceEntity>,
    @InjectRepository(CollectionEntity)
    private readonly colRepo: Repository<CollectionEntity>,
    @InjectRepository(ExpenseEntity)
    private readonly expRepo: Repository<ExpenseEntity>,
    @InjectRepository(AccountingVoucherEntity)
    private readonly voucherRepo: Repository<AccountingVoucherEntity>,
  ) {}

  async summary(user: AuthUser, scope: UserScope, filters: Filters) {
    this.validateDateRange(filters);

    const voucherQb = this.voucherRepo.createQueryBuilder('v');

    if (filters.from) {
      voucherQb.andWhere('v.voucher_date >= :from', { from: filters.from });
    }
    if (filters.to) {
      voucherQb.andWhere('v.voucher_date <= :to', { to: filters.to });
    }
    if (filters.territory_id !== undefined) {
      voucherQb.andWhere('v.territory_id = :territory_id', {
        territory_id: filters.territory_id,
      });
    }
    if (filters.party_id !== undefined) {
      voucherQb.andWhere('v.party_id = :party_id', { party_id: filters.party_id });
    }
    if (filters.user_id !== undefined) {
      voucherQb.andWhere('v.user_id = :user_id', { user_id: filters.user_id });
    }
    if (filters.status) {
      voucherQb.andWhere('v.status = :status', { status: filters.status });
    }

    this.applyTerritoryScope(voucherQb, 'v.territory_id', user, scope);

    const vouchers = await voucherQb.getMany();

    const posted = vouchers.filter((x) => x.status === 'POSTED');
    const cancelled = vouchers.filter((x) => x.status === 'CANCELLED');
    const draft = vouchers.filter((x) => x.status === 'DRAFT');

    const debit = posted
      .filter((x) => x.voucher_type === 'DEBIT')
      .reduce((sum, x) => sum + Number(x.amount || 0), 0);

    const credit = posted
      .filter((x) => x.voucher_type === 'CREDIT')
      .reduce((sum, x) => sum + Number(x.amount || 0), 0);

    return {
      ok: true,
      filters: this.serializeFilters(filters),
      counts: {
        total: vouchers.length,
        posted: posted.length,
        cancelled: cancelled.length,
        draft: draft.length,
      },
      totals: {
        debit: Number(debit.toFixed(2)),
        credit: Number(credit.toFixed(2)),
        balance: Number((debit - credit).toFixed(2)),
      },
    };
  }

  async ledger(user: AuthUser, scope: UserScope, filters: Filters) {
    this.validateDateRange(filters);

    const [sales, collections, expenses, vouchers] = await Promise.all([
      this.getSalesLedgerRows(user, scope, filters),
      this.getCollectionLedgerRows(user, scope, filters),
      this.getExpenseLedgerRows(user, scope, filters),
      this.getVoucherLedgerRows(user, scope, filters),
    ]);

    const entries = [...sales, ...collections, ...expenses, ...vouchers].sort(
      (a, b) => {
        const d = String(b.entry_date).localeCompare(String(a.entry_date));
        if (d != 0) return d;
        return Number(b.id) - Number(a.id);
      },
    );

    const totals = entries.reduce(
      (acc, row) => {
        acc.debit += Number(row.debit || 0);
        acc.credit += Number(row.credit || 0);
        return acc;
      },
      { debit: 0, credit: 0 },
    );

    return {
      ok: true,
      filters: this.serializeFilters(filters),
      totals: {
        debit: Number(totals.debit.toFixed(2)),
        credit: Number(totals.credit.toFixed(2)),
        balance: Number((totals.debit - totals.credit).toFixed(2)),
      },
      entries,
    };
  }

  async listVouchers(user: AuthUser, scope: UserScope, filters: Filters) {
    this.validateDateRange(filters);

    const qb = this.voucherRepo
      .createQueryBuilder('v')
      .orderBy('v.id', 'DESC');

    if (filters.from) {
      qb.andWhere('v.voucher_date >= :from', { from: filters.from });
    }
    if (filters.to) {
      qb.andWhere('v.voucher_date <= :to', { to: filters.to });
    }
    if (filters.territory_id !== undefined) {
      qb.andWhere('v.territory_id = :territory_id', {
        territory_id: filters.territory_id,
      });
    }
    if (filters.party_id !== undefined) {
      qb.andWhere('v.party_id = :party_id', { party_id: filters.party_id });
    }
    if (filters.user_id !== undefined) {
      qb.andWhere('v.user_id = :user_id', { user_id: filters.user_id });
    }
    if (filters.status) {
      qb.andWhere('v.status = :status', { status: filters.status });
    }

    this.applyTerritoryScope(qb, 'v.territory_id', user, scope);

    const vouchers = await qb.getMany();

    return {
      ok: true,
      filters: this.serializeFilters(filters),
      vouchers,
    };
  }

  async voucherDetails(id: number, user: AuthUser, scope: UserScope) {
    const qb = this.voucherRepo.createQueryBuilder('v').where('v.id = :id', {
      id,
    });

    this.applyTerritoryScope(qb, 'v.territory_id', user, scope);

    const voucher = await qb.getOne();
    if (!voucher) {
      throw new NotFoundException('Voucher not found');
    }

    return {
      ok: true,
      voucher,
    };
  }

  async createVoucher(
    user: AuthUser,
    scope: UserScope,
    input: {
      voucher_date: string;
      voucher_type: 'DEBIT' | 'CREDIT';
      amount: number;
      territory_id?: number | null;
      party_id?: number | null;
      user_id?: number | null;
      reference_type?: string | null;
      reference_id?: number | null;
      description?: string | null;
      status?: AccountingVoucherStatus;
    },
  ) {
    if (!input.voucher_date) {
      throw new BadRequestException('voucher_date is required');
    }
    if (!['DEBIT', 'CREDIT'].includes(String(input.voucher_type))) {
      throw new BadRequestException('voucher_type must be DEBIT or CREDIT');
    }

    const amount = Number(input.amount);
    if (!amount || amount <= 0) {
      throw new BadRequestException('amount must be greater than 0');
    }

    const territoryId =
      input.territory_id === undefined || input.territory_id === null
        ? null
        : Number(input.territory_id);

    this.assertTerritoryAllowed(user, scope, territoryId);

    const status = this.normalizeVoucherStatus(input.status || 'POSTED');
    const voucher_no = await this.nextVoucherNo();

    const row = this.voucherRepo.create({
      voucher_no,
      voucher_date: input.voucher_date,
      voucher_type: input.voucher_type as AccountingVoucherType,
      amount: Number(amount.toFixed(2)),
      territory_id: territoryId,
      party_id:
        input.party_id === undefined || input.party_id === null
          ? null
          : Number(input.party_id),
      user_id:
        input.user_id === undefined || input.user_id === null
          ? null
          : Number(input.user_id),
      reference_type: input.reference_type?.trim() || null,
      reference_id:
        input.reference_id === undefined || input.reference_id === null
          ? null
          : Number(input.reference_id),
      description: input.description?.trim() || null,
      status,
      approved_at: status === 'POSTED' ? new Date() : null,
      created_by: Number(user?.sub ?? user?.id ?? 0) || null,
      version: 1,
    });

    const voucher = await this.voucherRepo.save(row);

    return {
      ok: true,
      voucher,
    };
  }

  async updateVoucherStatus(
    id: number,
    user: AuthUser,
    scope: UserScope,
    input: {
      status: AccountingVoucherStatus;
    },
  ) {
    const qb = this.voucherRepo.createQueryBuilder('v').where('v.id = :id', {
      id,
    });

    this.applyTerritoryScope(qb, 'v.territory_id', user, scope);

    const voucher = await qb.getOne();
    if (!voucher) {
      throw new NotFoundException('Voucher not found');
    }

    const nextStatus = this.normalizeVoucherStatus(input.status);

    if (voucher.status === nextStatus) {
      return {
        ok: true,
        voucher,
      };
    }

    voucher.status = nextStatus;
    voucher.approved_at = nextStatus === 'POSTED' ? new Date() : null;
    voucher.version = Number(voucher.version || 1) + 1;

    const saved = await this.voucherRepo.save(voucher);

    return {
      ok: true,
      voucher: saved,
    };
  }

  private normalizeVoucherStatus(value: string): AccountingVoucherStatus {
    const status = String(value || '').toUpperCase().trim();

    if (!['DRAFT', 'POSTED', 'CANCELLED'].includes(status)) {
      throw new BadRequestException(
        'status must be DRAFT, POSTED or CANCELLED',
      );
    }

    return status as AccountingVoucherStatus;
  }

  private async nextVoucherNo() {
    const count = await this.voucherRepo.count();
    return `VCH-${String(count + 1).padStart(6, '0')}`;
  }

  private async getSalesLedgerRows(
    user: AuthUser,
    scope: UserScope,
    filters: Filters,
  ) {
    const qb = this.invRepo.createQueryBuilder('inv');

    qb.andWhere('inv.status = :status', { status: 'APPROVED' });

    if (filters.from) {
      qb.andWhere('inv.invoice_date >= :from', { from: filters.from });
    }
    if (filters.to) {
      qb.andWhere('inv.invoice_date <= :to', { to: filters.to });
    }
    if (filters.territory_id !== undefined) {
      qb.andWhere('inv.territory_id = :territory_id', {
        territory_id: filters.territory_id,
      });
    }
    if (filters.party_id !== undefined) {
      qb.andWhere('inv.party_id = :party_id', { party_id: filters.party_id });
    }
    if (filters.user_id !== undefined) {
      qb.andWhere('inv.mpo_user_id = :user_id', { user_id: filters.user_id });
    }

    this.applyTerritoryScope(qb, 'inv.territory_id', user, scope);

    const rows = await qb.getMany();

    return rows.map((row) => ({
      id: Number(row.id),
      entry_date: row.invoice_date,
      entity_type: 'INVOICE',
      entity_id: Number(row.id),
      reference_no: row.invoice_no,
      territory_id: Number(row.territory_id),
      party_id: Number(row.party_id),
      user_id: Number(row.mpo_user_id),
      description: row.remarks ?? 'Approved sales invoice',
      debit: Number(Number(row.net_total || 0).toFixed(2)),
      credit: 0,
      amount: Number(Number(row.net_total || 0).toFixed(2)),
      status: row.status,
    }));
  }

  private async getCollectionLedgerRows(
    user: AuthUser,
    scope: UserScope,
    filters: Filters,
  ) {
    const qb = this.colRepo.createQueryBuilder('col');

    qb.andWhere('col.status = :status', { status: 'APPROVED' });

    if (filters.from) {
      qb.andWhere('col.collection_date >= :from', { from: filters.from });
    }
    if (filters.to) {
      qb.andWhere('col.collection_date <= :to', { to: filters.to });
    }
    if (filters.territory_id !== undefined) {
      qb.andWhere('col.territory_id = :territory_id', {
        territory_id: filters.territory_id,
      });
    }
    if (filters.party_id !== undefined) {
      qb.andWhere('col.party_id = :party_id', { party_id: filters.party_id });
    }
    if (filters.user_id !== undefined) {
      qb.andWhere('col.mpo_user_id = :user_id', { user_id: filters.user_id });
    }

    this.applyTerritoryScope(qb, 'col.territory_id', user, scope);

    const rows = await qb.getMany();

return rows.map((row) => ({
  id: Number(row.id),
  entry_date: row.collection_date,
  entity_type: 'COLLECTION',
  entity_id: Number(row.id),
  reference_no: row.reference_no ?? row.collection_no,
  territory_id: Number(row.territory_id),
  party_id: Number(row.party_id),
  user_id: Number(row.mpo_user_id),
  description: `Approved collection entry (${row.method})`,
  debit: 0,
  credit: Number(Number(row.amount || 0).toFixed(2)),
  amount: Number(Number(row.amount || 0).toFixed(2)),
  status: row.status,
}));
  }

  private async getExpenseLedgerRows(
    user: AuthUser,
    scope: UserScope,
    filters: Filters,
  ) {
    const qb = this.expRepo.createQueryBuilder('exp');

    qb.andWhere('exp.status = :status', { status: 'APPROVED' });

    if (filters.from) {
      qb.andWhere('exp.expense_date >= :from', { from: filters.from });
    }
    if (filters.to) {
      qb.andWhere('exp.expense_date <= :to', { to: filters.to });
    }
    if (filters.territory_id !== undefined) {
      qb.andWhere('exp.territory_id = :territory_id', {
        territory_id: filters.territory_id,
      });
    }
    if (filters.user_id !== undefined) {
      qb.andWhere('exp.user_id = :user_id', { user_id: filters.user_id });
    }

    this.applyTerritoryScope(qb, 'exp.territory_id', user, scope);

    const rows = await qb.getMany();

    return rows.map((row) => ({
      id: Number(row.id),
      entry_date: row.expense_date,
      entity_type: 'EXPENSE',
      entity_id: Number(row.id),
      reference_no: `EXP-${row.id}`,
      territory_id: Number(row.territory_id),
      party_id: null,
      user_id: Number(row.user_id),
      description: row.note ?? 'Approved expense entry',
      debit: Number(Number(row.amount || 0).toFixed(2)),
      credit: 0,
      amount: Number(Number(row.amount || 0).toFixed(2)),
      status: row.status,
    }));
  }

  private async getVoucherLedgerRows(
    user: AuthUser,
    scope: UserScope,
    filters: Filters,
  ) {
    const qb = this.voucherRepo.createQueryBuilder('v');

    qb.andWhere('v.status = :status', {
      status: filters.status ? filters.status : 'POSTED',
    });

    if (filters.from) {
      qb.andWhere('v.voucher_date >= :from', { from: filters.from });
    }
    if (filters.to) {
      qb.andWhere('v.voucher_date <= :to', { to: filters.to });
    }
    if (filters.territory_id !== undefined) {
      qb.andWhere('v.territory_id = :territory_id', {
        territory_id: filters.territory_id,
      });
    }
    if (filters.party_id !== undefined) {
      qb.andWhere('v.party_id = :party_id', { party_id: filters.party_id });
    }
    if (filters.user_id !== undefined) {
      qb.andWhere('v.user_id = :user_id', { user_id: filters.user_id });
    }

    this.applyTerritoryScope(qb, 'v.territory_id', user, scope);

    const rows = await qb.getMany();

    return rows.map((row) => ({
      id: Number(row.id),
      entry_date: row.voucher_date,
      entity_type: 'VOUCHER',
      entity_id: Number(row.id),
      reference_no: row.voucher_no,
      territory_id: row.territory_id ? Number(row.territory_id) : null,
      party_id: row.party_id ? Number(row.party_id) : null,
      user_id: row.user_id ? Number(row.user_id) : null,
      description: row.description ?? 'Manual accounting voucher',
      debit:
        row.voucher_type === 'DEBIT'
          ? Number(Number(row.amount || 0).toFixed(2))
          : 0,
      credit:
        row.voucher_type === 'CREDIT'
          ? Number(Number(row.amount || 0).toFixed(2))
          : 0,
      amount: Number(Number(row.amount || 0).toFixed(2)),
      status: row.status,
    }));
  }

  private validateDateRange(filters: Filters) {
    if (filters.from && Number.isNaN(Date.parse(filters.from))) {
      throw new BadRequestException('Invalid from date');
    }
    if (filters.to && Number.isNaN(Date.parse(filters.to))) {
      throw new BadRequestException('Invalid to date');
    }
    if (filters.from && filters.to && filters.from > filters.to) {
      throw new BadRequestException('from date cannot be greater than to date');
    }
  }

  private serializeFilters(filters: Filters) {
    return {
      from: filters.from ?? null,
      to: filters.to ?? null,
      territory_id:
        filters.territory_id === undefined ? null : filters.territory_id,
      party_id: filters.party_id === undefined ? null : filters.party_id,
      user_id: filters.user_id === undefined ? null : filters.user_id,
      status: filters.status ?? null,
    };
  }

  private applyTerritoryScope<T extends ObjectLiteral>(
    qb: SelectQueryBuilder<T>,
    column: string,
    user: AuthUser,
    scope: UserScope,
  ) {
    if (String(user?.role) === Role.SUPER_ADMIN) {
      return;
    }

    const territoryIds = (scope?.territoryIds ?? [])
      .map((x) => Number(x))
      .filter((x) => Number.isFinite(x));

    if (!territoryIds.length) {
      qb.andWhere('1 = 0');
      return;
    }

    qb.andWhere(`${column} IN (:...territoryIds)`, { territoryIds });
  }

  private assertTerritoryAllowed(
    user: AuthUser,
    scope: UserScope,
    territoryId: number | null,
  ) {
    if (String(user?.role) === Role.SUPER_ADMIN) {
      return;
    }

    if (territoryId === null) {
      return;
    }

    const territoryIds = (scope?.territoryIds ?? [])
      .map((x) => Number(x))
      .filter((x) => Number.isFinite(x));

    if (!territoryIds.includes(Number(territoryId))) {
      throw new BadRequestException(
        'You are not allowed to create voucher for this territory',
      );
    }
  }
}