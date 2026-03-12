import { BadRequestException, Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { ObjectLiteral, Repository, SelectQueryBuilder } from 'typeorm';
import { Role } from '../auth/roles.enum';
import { InvoiceEntity } from '../invoices/invoice.entity';
import { CollectionEntity } from '../collections/collection.entity';
import { ExpenseEntity } from '../expenses/expense.entity';
import { ProductEntity } from '../products/product.entity';

type AuthUser = {
  sub?: number;
  id?: number;
  role?: Role | string;
};

type UserScope = {
  territoryIds?: number[] | null;
};

type ReportFilters = {
  from?: string;
  to?: string;
  territory_id?: number;
  party_id?: number;
  user_id?: number;
};

@Injectable()
export class ReportsService {
  constructor(
    @InjectRepository(InvoiceEntity)
    private readonly invRepo: Repository<InvoiceEntity>,
    @InjectRepository(CollectionEntity)
    private readonly colRepo: Repository<CollectionEntity>,
    @InjectRepository(ExpenseEntity)
    private readonly expRepo: Repository<ExpenseEntity>,
    @InjectRepository(ProductEntity)
    private readonly productRepo: Repository<ProductEntity>,
  ) {}

  async salesSummary(user: AuthUser, scope: UserScope, filters: ReportFilters) {
    this.validateDateRange(filters);

    const qb = this.invRepo.createQueryBuilder('inv');

    this.applyInvoiceFilters(qb, user, scope, filters);

    const raw = await qb
      .select('COUNT(*)', 'total_invoices')
      .addSelect(
        "SUM(CASE WHEN inv.status = 'APPROVED' THEN 1 ELSE 0 END)",
        'approved_invoices',
      )
      .addSelect(
        "COALESCE(SUM(CASE WHEN inv.status = 'APPROVED' THEN inv.subtotal ELSE 0 END), 0)",
        'gross_sales',
      )
      .addSelect(
        "COALESCE(SUM(CASE WHEN inv.status = 'APPROVED' THEN inv.discount_amount ELSE 0 END), 0)",
        'total_discount',
      )
      .addSelect(
        "COALESCE(SUM(CASE WHEN inv.status = 'APPROVED' THEN inv.net_total ELSE 0 END), 0)",
        'net_sales',
      )
      .addSelect(
        "COALESCE(SUM(CASE WHEN inv.status = 'APPROVED' THEN inv.received_amount ELSE 0 END), 0)",
        'received_amount',
      )
      .addSelect(
        "COALESCE(SUM(CASE WHEN inv.status = 'APPROVED' THEN inv.due_amount ELSE 0 END), 0)",
        'outstanding_due',
      )
      .addSelect('MIN(inv.invoice_date)', 'first_invoice_date')
      .addSelect('MAX(inv.invoice_date)', 'last_invoice_date')
      .getRawOne();

    return {
      ok: true,
      filters: this.serializeFilters(filters),
      summary: {
        total_invoices: Number(raw?.total_invoices ?? 0),
        approved_invoices: Number(raw?.approved_invoices ?? 0),
        gross_sales: Number(raw?.gross_sales ?? 0),
        total_discount: Number(raw?.total_discount ?? 0),
        net_sales: Number(raw?.net_sales ?? 0),
        received_amount: Number(raw?.received_amount ?? 0),
        outstanding_due: Number(raw?.outstanding_due ?? 0),
        first_invoice_date: raw?.first_invoice_date ?? null,
        last_invoice_date: raw?.last_invoice_date ?? null,
      },
    };
  }

  async collectionsSummary(user: AuthUser, scope: UserScope, filters: ReportFilters) {
    this.validateDateRange(filters);

    const qb = this.colRepo.createQueryBuilder('col');

    this.applyCollectionFilters(qb, user, scope, filters);

    const raw = await qb
      .select('COUNT(*)', 'total_collections')
      .addSelect(
        "SUM(CASE WHEN col.status = 'APPROVED' THEN 1 ELSE 0 END)",
        'approved_collections',
      )
      .addSelect('COALESCE(SUM(col.amount), 0)', 'total_amount')
      .addSelect(
        "COALESCE(SUM(CASE WHEN col.status = 'APPROVED' THEN col.amount ELSE 0 END), 0)",
        'approved_amount',
      )
      .addSelect(
        "COALESCE(SUM(CASE WHEN col.status = 'APPROVED' THEN (col.amount - col.unused_amount) ELSE 0 END), 0)",
        'allocated_amount',
      )
      .addSelect(
        "COALESCE(SUM(CASE WHEN col.status = 'APPROVED' THEN col.unused_amount ELSE 0 END), 0)",
        'unused_amount',
      )
      .addSelect('MIN(col.collection_date)', 'first_collection_date')
      .addSelect('MAX(col.collection_date)', 'last_collection_date')
      .getRawOne();

    return {
      ok: true,
      filters: this.serializeFilters(filters),
      summary: {
        total_collections: Number(raw?.total_collections ?? 0),
        approved_collections: Number(raw?.approved_collections ?? 0),
        total_amount: Number(raw?.total_amount ?? 0),
        approved_amount: Number(raw?.approved_amount ?? 0),
        allocated_amount: Number(raw?.allocated_amount ?? 0),
        unused_amount: Number(raw?.unused_amount ?? 0),
        first_collection_date: raw?.first_collection_date ?? null,
        last_collection_date: raw?.last_collection_date ?? null,
      },
    };
  }

  async stockSummary(user: AuthUser, scope: UserScope, filters: ReportFilters) {
    this.validateDateRange(filters);

    const products = await this.productRepo.find({
      order: { id: 'DESC' as any },
    });

    const activeProducts = products.filter((p) => Number(p.is_active) === 1);
    const totalStockQty = activeProducts.reduce((sum, p) => {
      return sum + Number(p.in_stock || 0);
    }, 0);
    const stockValue = activeProducts.reduce((sum, p) => {
      return sum + Number(p.in_stock || 0) * Number(p.purchase_price || 0);
    }, 0);
    const saleValue = activeProducts.reduce((sum, p) => {
      return sum + Number(p.in_stock || 0) * Number(p.sale_price || 0);
    }, 0);
    const lowStockCount = activeProducts.filter((p) => {
      return Number(p.in_stock || 0) <= Number(p.reorder_level || 0);
    }).length;
    const outOfStockCount = activeProducts.filter((p) => {
      return Number(p.in_stock || 0) <= 0;
    }).length;

    return {
      ok: true,
      filters: this.serializeFilters(filters),
      summary: {
        total_products: products.length,
        active_products: activeProducts.length,
        total_stock_qty: Number(totalStockQty.toFixed(2)),
        stock_value_purchase: Number(stockValue.toFixed(2)),
        stock_value_sale: Number(saleValue.toFixed(2)),
        low_stock_count: lowStockCount,
        out_of_stock_count: outOfStockCount,
      },
      note:
        'Stock summary is calculated from products table only. Date, territory, party, and user filters are accepted for API consistency but not applied because current stock data model has no per-territory or per-user stock ledger.',
    };
  }

  async expenseSummary(user: AuthUser, scope: UserScope, filters: ReportFilters) {
    this.validateDateRange(filters);

    const qb = this.expRepo.createQueryBuilder('exp');

    this.applyExpenseFilters(qb, user, scope, filters);

    const raw = await qb
      .select('COUNT(*)', 'total_expenses')
      .addSelect(
        "SUM(CASE WHEN exp.status = 'APPROVED' THEN 1 ELSE 0 END)",
        'approved_expenses',
      )
      .addSelect('COALESCE(SUM(exp.amount), 0)', 'total_amount')
      .addSelect(
        "COALESCE(SUM(CASE WHEN exp.status = 'APPROVED' THEN exp.amount ELSE 0 END), 0)",
        'approved_amount',
      )
      .addSelect(
        "COALESCE(SUM(CASE WHEN exp.status = 'DECLINED' THEN exp.amount ELSE 0 END), 0)",
        'declined_amount',
      )
      .addSelect('MIN(exp.expense_date)', 'first_expense_date')
      .addSelect('MAX(exp.expense_date)', 'last_expense_date')
      .getRawOne();

    return {
      ok: true,
      filters: this.serializeFilters(filters),
      summary: {
        total_expenses: Number(raw?.total_expenses ?? 0),
        approved_expenses: Number(raw?.approved_expenses ?? 0),
        total_amount: Number(raw?.total_amount ?? 0),
        approved_amount: Number(raw?.approved_amount ?? 0),
        declined_amount: Number(raw?.declined_amount ?? 0),
        first_expense_date: raw?.first_expense_date ?? null,
        last_expense_date: raw?.last_expense_date ?? null,
      },
    };
  }

  private validateDateRange(filters: ReportFilters) {
    if (filters.from && filters.to && filters.from > filters.to) {
      throw new BadRequestException('from date cannot be greater than to date');
    }
  }

  private applyInvoiceFilters(
    qb: SelectQueryBuilder<InvoiceEntity>,
    user: AuthUser,
    scope: UserScope,
    filters: ReportFilters,
  ) {
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
  }

  private applyCollectionFilters(
    qb: SelectQueryBuilder<CollectionEntity>,
    user: AuthUser,
    scope: UserScope,
    filters: ReportFilters,
  ) {
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
  }

  private applyExpenseFilters(
    qb: SelectQueryBuilder<ExpenseEntity>,
    user: AuthUser,
    scope: UserScope,
    filters: ReportFilters,
  ) {
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
  }

  private applyTerritoryScope<T extends ObjectLiteral>(
    qb: SelectQueryBuilder<T>,
    territoryColumn: string,
    user: AuthUser,
    scope: UserScope,
  ) {
    const role = String(user?.role ?? '').toUpperCase();
    if (role === Role.SUPER_ADMIN) {
      return;
    }

    const territoryIds = Array.isArray(scope?.territoryIds)
      ? scope.territoryIds.map((x) => Number(x)).filter((x) => x > 0)
      : [];

    if (!territoryIds.length) {
      qb.andWhere('1 = 0');
      return;
    }

    qb.andWhere(`${territoryColumn} IN (:...territoryIds)`, { territoryIds });
  }

  private serializeFilters(filters: ReportFilters) {
    return {
      from: filters.from ?? null,
      to: filters.to ?? null,
      territory_id: filters.territory_id ?? null,
      party_id: filters.party_id ?? null,
      user_id: filters.user_id ?? null,
    };
  }
}