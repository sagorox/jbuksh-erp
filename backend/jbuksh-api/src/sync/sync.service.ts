import { BadRequestException, Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { In, MoreThan, Repository } from 'typeorm';

import { Role } from '../auth/roles.enum';
import { PartyEntity } from '../parties/party.entity';
import { InvoiceEntity } from '../invoices/invoice.entity';
import { CollectionEntity } from '../collections/collection.entity';
import { ExpenseEntity } from '../expenses/expense.entity';
import { AttendanceEntity } from '../attendance/attendance.entity';
import { ProductEntity } from '../products/product.entity';
import { CategoryEntity } from '../products/category.entity';
import { TerritoryEntity } from '../geo/territory.entity';
import { DeliveryEntity } from '../deliveries/delivery.entity';

import {
  SyncChangeLogEntity,
  SyncEntityType,
  SyncOperation,
} from './sync-change-log.entity';
import { AuditLogEntity } from './audit-log.entity';
import { SyncPushDto } from './sync.dto';

type AuthUser = {
  sub: number;
  role: Role;
};

type UserScope = {
  territoryIds: number[] | null;
};

@Injectable()
export class SyncService {
  constructor(
    @InjectRepository(PartyEntity)
    private readonly partyRepo: Repository<PartyEntity>,
    @InjectRepository(InvoiceEntity)
    private readonly invoiceRepo: Repository<InvoiceEntity>,
    @InjectRepository(CollectionEntity)
    private readonly collectionRepo: Repository<CollectionEntity>,
    @InjectRepository(ExpenseEntity)
    private readonly expenseRepo: Repository<ExpenseEntity>,
    @InjectRepository(AttendanceEntity)
    private readonly attendanceRepo: Repository<AttendanceEntity>,
    @InjectRepository(ProductEntity)
    private readonly productRepo: Repository<ProductEntity>,
    @InjectRepository(CategoryEntity)
    private readonly categoryRepo: Repository<CategoryEntity>,
    @InjectRepository(TerritoryEntity)
    private readonly territoryRepo: Repository<TerritoryEntity>,
    @InjectRepository(DeliveryEntity)
    private readonly deliveryRepo: Repository<DeliveryEntity>,
    @InjectRepository(SyncChangeLogEntity)
    private readonly syncLogRepo: Repository<SyncChangeLogEntity>,
    @InjectRepository(AuditLogEntity)
    private readonly auditRepo: Repository<AuditLogEntity>,
  ) {}

  async bootstrap(user: AuthUser, scope: UserScope) {
    const territoryIds = scope?.territoryIds ?? [];

    const categories = await this.categoryRepo.find({
      order: { id: 'ASC' as any },
    });

    const products = await this.productRepo.find({
      order: { id: 'ASC' as any },
    });

    if (user.role === Role.SUPER_ADMIN) {
      const territories = await this.territoryRepo.find({
        order: { id: 'ASC' as any },
      });

      const parties = await this.partyRepo.find({
        order: { id: 'DESC' as any },
        take: 1000,
      });

      const invoices = await this.invoiceRepo.find({
        order: { id: 'DESC' as any },
        take: 1000,
      });

      const collections = await this.collectionRepo.find({
        order: { id: 'DESC' as any },
        take: 1000,
      });

      const expenses = await this.expenseRepo.find({
        order: { id: 'DESC' as any },
        take: 1000,
      });

      const attendance = await this.attendanceRepo.find({
        order: { id: 'DESC' as any },
        take: 365,
      });

      const deliveries = await this.deliveryRepo.find({
        order: { id: 'DESC' as any },
        take: 1000,
      });

      return {
        serverTime: new Date().toISOString(),
        master: { categories, products, territories },
        scoped: { parties, invoices, collections, expenses, attendance, deliveries },
      };
    }

    const territories = territoryIds.length
      ? await this.territoryRepo.find({
          where: { id: In(territoryIds) },
          order: { id: 'ASC' as any },
        })
      : [];

    if (user.role === Role.MPO) {
      const parties = await this.partyRepo.find({
        where: { assigned_mpo_user_id: user.sub, is_active: 1 },
        order: { id: 'DESC' as any },
      });

      const invoices = await this.invoiceRepo.find({
        where: { mpo_user_id: user.sub },
        order: { id: 'DESC' as any },
      });

      const collections = await this.collectionRepo.find({
        where: { mpo_user_id: user.sub },
        order: { id: 'DESC' as any },
      });

      const expenses = await this.expenseRepo.find({
        where: { user_id: user.sub },
        order: { id: 'DESC' as any },
      });

      const attendance = await this.attendanceRepo.find({
        where: { user_id: user.sub },
        order: { id: 'DESC' as any },
      });

      const deliveries: DeliveryEntity[] = [];

      return {
        serverTime: new Date().toISOString(),
        master: { categories, products, territories },
        scoped: { parties, invoices, collections, expenses, attendance, deliveries },
      };
    }

    if (!territoryIds.length) {
      return {
        serverTime: new Date().toISOString(),
        master: { categories, products, territories: [] },
        scoped: {
          parties: [],
          invoices: [],
          collections: [],
          expenses: [],
          attendance: [],
          deliveries: [],
        },
      };
    }

    const parties = await this.partyRepo.find({
      where: { territory_id: In(territoryIds), is_active: 1 },
      order: { id: 'DESC' as any },
    });

    const invoices = await this.invoiceRepo.find({
      where: { territory_id: In(territoryIds) },
      order: { id: 'DESC' as any },
    });

    const collections = await this.collectionRepo.find({
      where: { territory_id: In(territoryIds) },
      order: { id: 'DESC' as any },
    });

    const expenses = await this.expenseRepo.find({
      where: { territory_id: In(territoryIds) },
      order: { id: 'DESC' as any },
    });

    const attendance = await this.attendanceRepo.find({
      where: { territory_id: In(territoryIds) },
      order: { id: 'DESC' as any },
    });

    const deliveries: DeliveryEntity[] = [];

    return {
      serverTime: new Date().toISOString(),
      master: { categories, products, territories },
      scoped: { parties, invoices, collections, expenses, attendance, deliveries },
    };
  }

  async pull(user: AuthUser, scope: UserScope, since?: string) {
    if (!since) {
      throw new BadRequestException('since is required');
    }

    const sinceDate = new Date(since);
    if (Number.isNaN(sinceDate.getTime())) {
      throw new BadRequestException('Invalid since timestamp');
    }

    const territoryIds = scope?.territoryIds ?? [];

    const logs = await this.syncLogRepo.find({
      where: { changed_at: MoreThan(sinceDate) },
      order: { changed_at: 'ASC' as any, id: 'ASC' as any },
    });

    const changes: any[] = [];

    for (const log of logs) {
      const allowed = await this.isLogVisibleToUser(log, user, territoryIds);
      if (!allowed) continue;

      changes.push({
        entity: String(log.entity_type).toLowerCase(),
        entity_id: log.entity_id,
        entity_uuid: log.entity_uuid,
        territory_id: log.territory_id,
        version: log.version,
        operation: log.operation,
        changed_at: log.changed_at,
      });
    }

    return {
      serverTime: new Date().toISOString(),
      changes,
    };
  }

  async push(user: AuthUser, scope: UserScope, dto: SyncPushDto) {
    const results: any[] = [];

    for (const change of dto?.changes || []) {
      try {
        const entity = String(change.entity || '').toLowerCase();
        const payload = change.payload || {};
        const uuid = change.uuid || payload.uuid || null;

        if (entity === 'invoice') {
          const saved = await this.handleInvoicePush(user, scope, uuid, payload);
          results.push({
            uuid,
            status: 'OK',
            server_id: saved.id,
            new_version: saved.version,
          });
          continue;
        }

        if (entity === 'collection') {
          const saved = await this.handleCollectionPush(user, scope, uuid, payload);
          results.push({
            uuid,
            status: 'OK',
            server_id: saved.id,
            new_version: saved.version,
          });
          continue;
        }

        if (entity === 'expense') {
          const saved = await this.handleExpensePush(user, scope, uuid, payload);
          results.push({
            uuid,
            status: 'OK',
            server_id: saved.id,
            new_version: saved.version,
          });
          continue;
        }

        if (entity === 'party') {
          const saved = await this.handlePartyPush(user, scope, uuid, payload);
          results.push({
            uuid,
            status: 'OK',
            server_id: saved.id,
            new_version: saved.version,
          });
          continue;
        }

        if (entity === 'attendance') {
          const saved = await this.handleAttendancePush(user, scope, uuid, payload);
          results.push({
            uuid,
            status: 'OK',
            server_id: saved.id,
            new_version: saved.version,
          });
          continue;
        }

        results.push({
          uuid,
          status: 'ERROR',
          message: `Unsupported entity: ${entity}`,
        });
      } catch (error: any) {
        results.push({
          uuid: change?.uuid || null,
          status: 'ERROR',
          message: error?.message || 'Push failed',
        });
      }
    }

    return { results };
  }

  private async isLogVisibleToUser(
    log: SyncChangeLogEntity,
    user: AuthUser,
    territoryIds: number[],
  ) {
    if (user.role === Role.SUPER_ADMIN) {
      return true;
    }

    if (user.role === Role.MPO) {
      if (log.entity_type === 'PARTY') {
        const row = await this.partyRepo.findOne({
          where: { id: Number(log.entity_id) },
        });
        return !!row && Number(row.assigned_mpo_user_id) === Number(user.sub);
      }

      if (log.entity_type === 'INVOICE') {
        const row = await this.invoiceRepo.findOne({
          where: { id: Number(log.entity_id) },
        });
        return !!row && Number(row.mpo_user_id) === Number(user.sub);
      }

      if (log.entity_type === 'COLLECTION') {
        const row = await this.collectionRepo.findOne({
          where: { id: Number(log.entity_id) },
        });
        return !!row && Number(row.mpo_user_id) === Number(user.sub);
      }

      if (log.entity_type === 'EXPENSE') {
        const row = await this.expenseRepo.findOne({
          where: { id: Number(log.entity_id) },
        });
        return !!row && Number(row.user_id) === Number(user.sub);
      }

      if (log.entity_type === 'ATTENDANCE') {
        const row = await this.attendanceRepo.findOne({
          where: { id: Number(log.entity_id) },
        });
        return !!row && Number(row.user_id) === Number(user.sub);
      }

if (log.entity_type === 'PRODUCT') {
  return true;
}

      if (log.entity_type === 'DELIVERY') {
        return false;
      }

      return false;
    }

if (log.entity_type === 'PRODUCT') {
  return true;
}

    if (!territoryIds.length) {
      return false;
    }

    if (log.entity_type === 'PARTY') {
      const row = await this.partyRepo.findOne({
        where: { id: Number(log.entity_id) },
      });
      return !!row && territoryIds.includes(Number(row.territory_id));
    }

    if (log.entity_type === 'INVOICE') {
      const row = await this.invoiceRepo.findOne({
        where: { id: Number(log.entity_id) },
      });
      return !!row && territoryIds.includes(Number(row.territory_id));
    }

    if (log.entity_type === 'COLLECTION') {
      const row = await this.collectionRepo.findOne({
        where: { id: Number(log.entity_id) },
      });
      return !!row && territoryIds.includes(Number(row.territory_id));
    }

    if (log.entity_type === 'EXPENSE') {
      const row = await this.expenseRepo.findOne({
        where: { id: Number(log.entity_id) },
      });
      return !!row && territoryIds.includes(Number(row.territory_id));
    }

    if (log.entity_type === 'ATTENDANCE') {
      const row = await this.attendanceRepo.findOne({
        where: { id: Number(log.entity_id) },
      });
      return !!row && territoryIds.includes(Number(row.territory_id));
    }

if (log.entity_type === 'DELIVERY') {
  return false;
}
  }

  private async handleInvoicePush(
    user: AuthUser,
    scope: UserScope,
    uuid: string,
    payload: any,
  ) {
    const territoryIds = scope?.territoryIds ?? [];
    const territoryId = Number(payload.territory_id || 0);

    if (user.role !== Role.SUPER_ADMIN && !territoryIds.includes(territoryId)) {
      throw new BadRequestException('Invoice territory out of user scope');
    }

    let row: InvoiceEntity | null = null;
    if (uuid) {
      row = await this.invoiceRepo.findOne({ where: { uuid } });
    }

    const before = row ? { ...row } : null;

    if (!row) {
      row = this.invoiceRepo.create({
        uuid,
        invoice_no: payload.invoice_no || this.generateDocNo('INV'),
        mpo_user_id:
          user.role === Role.MPO
            ? user.sub
            : Number(payload.mpo_user_id || user.sub || 0),
        territory_id: territoryId,
        party_id: Number(payload.party_id || 0),
        invoice_date: payload.invoice_date || new Date().toISOString().slice(0, 10),
        invoice_time: payload.invoice_time || '00:00:00',
        status: payload.status || 'DRAFT',
        subtotal: Number(payload.subtotal || 0),
        discount_percent: Number(payload.discount_percent || 0),
        discount_amount: Number(payload.discount_amount || 0),
        net_total: Number(payload.net_total || 0),
        received_amount: Number(payload.received_amount || 0),
        due_amount: Number(payload.due_amount || 0),
        remarks: payload.remarks || null,
        pdf_url: payload.pdf_url || null,
        items_json: payload.items
          ? JSON.stringify(payload.items)
          : payload.items_json || null,
        version: 1,
      });
    } else {
      row.invoice_no = payload.invoice_no || row.invoice_no;
      row.mpo_user_id =
        user.role === Role.MPO
          ? user.sub
          : Number(payload.mpo_user_id || row.mpo_user_id);
      row.territory_id = territoryId || row.territory_id;
      row.party_id = Number(payload.party_id || row.party_id);
      row.invoice_date = payload.invoice_date || row.invoice_date;
      row.invoice_time = payload.invoice_time || row.invoice_time;
      row.status = payload.status || row.status;
      row.subtotal = Number(payload.subtotal ?? row.subtotal ?? 0);
      row.discount_percent = Number(
        payload.discount_percent ?? row.discount_percent ?? 0,
      );
      row.discount_amount = Number(
        payload.discount_amount ?? row.discount_amount ?? 0,
      );
      row.net_total = Number(payload.net_total ?? row.net_total ?? 0);
      row.received_amount = Number(
        payload.received_amount ?? row.received_amount ?? 0,
      );
      row.due_amount = Number(payload.due_amount ?? row.due_amount ?? 0);
      row.remarks = payload.remarks ?? row.remarks ?? null;
      row.pdf_url = payload.pdf_url ?? row.pdf_url ?? null;
      row.items_json = payload.items
        ? JSON.stringify(payload.items)
        : payload.items_json ?? row.items_json ?? null;
      row.version = Number(row.version || 1) + 1;
    }

    const saved = await this.invoiceRepo.save(row);
    await this.writeLogAndAudit(
      'INVOICE',
      saved.uuid,
      saved.id,
      saved.territory_id,
      saved.version,
      'UPSERT',
      user,
      before,
      saved,
      dtoDeviceId(undefined),
    );
    return saved;
  }

  private async handleCollectionPush(
    user: AuthUser,
    scope: UserScope,
    uuid: string,
    payload: any,
  ) {
    const territoryIds = scope?.territoryIds ?? [];
    const territoryId = Number(payload.territory_id || 0);

    if (user.role !== Role.SUPER_ADMIN && !territoryIds.includes(territoryId)) {
      throw new BadRequestException('Collection territory out of user scope');
    }

    let row: CollectionEntity | null = null;
    if (uuid) {
      row = await this.collectionRepo.findOne({ where: { uuid } });
    }

    const before = row ? { ...row } : null;

    if (!row) {
      row = this.collectionRepo.create({
        uuid,
        collection_no: payload.collection_no || this.generateDocNo('COL'),
        mpo_user_id:
          user.role === Role.MPO
            ? user.sub
            : Number(payload.mpo_user_id || user.sub || 0),
        territory_id: territoryId,
        party_id: Number(payload.party_id || 0),
        collection_date:
          payload.collection_date || new Date().toISOString().slice(0, 10),
        method: payload.method || 'CASH',
        amount: Number(payload.amount || 0),
        reference_no: payload.reference_no || null,
        status: payload.status || 'APPROVED',
        unused_amount: Number(payload.unused_amount || payload.amount || 0),
        allocations_json: payload.allocations
          ? JSON.stringify(payload.allocations)
          : payload.allocations_json || null,
        version: 1,
      });
    } else {
      row.collection_no = payload.collection_no || row.collection_no;
      row.mpo_user_id =
        user.role === Role.MPO
          ? user.sub
          : Number(payload.mpo_user_id || row.mpo_user_id);
      row.territory_id = territoryId || row.territory_id;
      row.party_id = Number(payload.party_id || row.party_id);
      row.collection_date = payload.collection_date || row.collection_date;
      row.method = payload.method || row.method;
      row.amount = Number(payload.amount ?? row.amount ?? 0);
      row.reference_no = payload.reference_no ?? row.reference_no ?? null;
      row.status = payload.status || row.status;
      row.unused_amount = Number(
        payload.unused_amount ?? row.unused_amount ?? row.amount ?? 0,
      );
      row.allocations_json = payload.allocations
        ? JSON.stringify(payload.allocations)
        : payload.allocations_json ?? row.allocations_json ?? null;
      row.version = Number(row.version || 1) + 1;
    }

    const saved = await this.collectionRepo.save(row);
    await this.writeLogAndAudit(
      'COLLECTION',
      saved.uuid,
      saved.id,
      saved.territory_id,
      saved.version,
      'UPSERT',
      user,
      before,
      saved,
      dtoDeviceId(undefined),
    );
    return saved;
  }

  private async handleExpensePush(
    user: AuthUser,
    scope: UserScope,
    uuid: string,
    payload: any,
  ) {
    const territoryIds = scope?.territoryIds ?? [];
    const territoryId = Number(payload.territory_id || 0);

    if (user.role !== Role.SUPER_ADMIN && !territoryIds.includes(territoryId)) {
      throw new BadRequestException('Expense territory out of user scope');
    }

    let row: ExpenseEntity | null = null;
    if (uuid) {
      row = await this.expenseRepo.findOne({ where: { uuid } });
    }

    const before = row ? { ...row } : null;

    if (!row) {
      row = this.expenseRepo.create({
        uuid,
        user_id:
          user.role === Role.MPO
            ? user.sub
            : Number(payload.user_id || user.sub || 0),
        territory_id: territoryId,
        expense_date: payload.expense_date || new Date().toISOString().slice(0, 10),
        head_id: Number(payload.head_id || 0),
        amount: Number(payload.amount || 0),
        note: payload.note || null,
        status: 'APPROVED',
        version: 1,
      });
    } else {
      row.user_id =
        user.role === Role.MPO
          ? user.sub
          : Number(payload.user_id || row.user_id);
      row.territory_id = territoryId || row.territory_id;
      row.expense_date = payload.expense_date || row.expense_date;
      row.head_id = Number(payload.head_id || row.head_id);
      row.amount = Number(payload.amount ?? row.amount ?? 0);
      row.note = payload.note ?? row.note ?? null;
      row.version = Number(row.version || 1) + 1;
    }

    const saved = await this.expenseRepo.save(row);
    await this.writeLogAndAudit(
      'EXPENSE',
      saved.uuid,
      saved.id,
      saved.territory_id,
      saved.version,
      'UPSERT',
      user,
      before,
      saved,
      dtoDeviceId(undefined),
    );
    return saved;
  }

  private async handlePartyPush(
    user: AuthUser,
    scope: UserScope,
    uuid: string,
    payload: any,
  ) {
    const territoryIds = scope?.territoryIds ?? [];
    const territoryId = Number(payload.territory_id || 0);

    if (user.role !== Role.SUPER_ADMIN && !territoryIds.includes(territoryId)) {
      throw new BadRequestException('Party territory out of user scope');
    }

    let row: PartyEntity | null = null;
    if (uuid) {
      row = await this.partyRepo.findOne({ where: { uuid } });
    }

    const before = row ? { ...row } : null;

    if (!row) {
      row = this.partyRepo.create({
        uuid,
        territory_id: territoryId,
        assigned_mpo_user_id:
          user.role === Role.MPO
            ? user.sub
            : Number(payload.assigned_mpo_user_id || 0) || null,
        party_code: payload.party_code || this.generateDocNo('PTY'),
        name: payload.name || 'Unnamed Party',
        credit_limit: Number(payload.credit_limit || 0),
        is_active: Number(payload.is_active ?? 1),
        version: 1,
      });
    } else {
      row.territory_id = territoryId || row.territory_id;
      row.assigned_mpo_user_id =
        user.role === Role.MPO
          ? user.sub
          : payload.assigned_mpo_user_id !== undefined
            ? Number(payload.assigned_mpo_user_id || 0) || null
            : row.assigned_mpo_user_id;
      row.party_code = payload.party_code || row.party_code;
      row.name = payload.name || row.name;
      row.credit_limit = Number(payload.credit_limit ?? row.credit_limit ?? 0);
      row.is_active = Number(payload.is_active ?? row.is_active ?? 1);
      row.version = Number(row.version || 1) + 1;
    }

    const saved = await this.partyRepo.save(row);
    await this.writeLogAndAudit(
      'PARTY',
      saved.uuid,
      saved.id,
      saved.territory_id,
      saved.version,
      'UPSERT',
      user,
      before,
      saved,
      dtoDeviceId(undefined),
    );
    return saved;
  }

  private async handleAttendancePush(
    user: AuthUser,
    scope: UserScope,
    uuid: string,
    payload: any,
  ) {
    const territoryIds = scope?.territoryIds ?? [];
    const territoryId = Number(payload.territory_id || 0);

    if (
      user.role !== Role.SUPER_ADMIN &&
      territoryId &&
      !territoryIds.includes(territoryId)
    ) {
      throw new BadRequestException('Attendance territory out of user scope');
    }

    let row: AttendanceEntity | null = null;
    if (uuid) {
      row = await this.attendanceRepo.findOne({ where: { uuid } });
    }

    const before = row ? { ...row } : null;

    if (!row) {
      row = this.attendanceRepo.create({
        uuid,
        user_id:
          user.role === Role.MPO
            ? user.sub
            : Number(payload.user_id || user.sub || 0),
        territory_id: territoryId || null,
        att_date: payload.att_date || new Date().toISOString().slice(0, 10),
        check_in_at: payload.check_in_at ? new Date(payload.check_in_at) : null,
        check_out_at: payload.check_out_at ? new Date(payload.check_out_at) : null,
        status: payload.status || 'PENDING',
        note: payload.note || null,
        geo_lat: payload.geo_lat ?? null,
        geo_lng: payload.geo_lng ?? null,
        version: 1,
      });
    } else {
      row.user_id =
        user.role === Role.MPO
          ? user.sub
          : Number(payload.user_id || row.user_id);
      row.territory_id = territoryId || row.territory_id || null;
      row.att_date = payload.att_date || row.att_date;
      row.check_in_at = payload.check_in_at
        ? new Date(payload.check_in_at)
        : row.check_in_at ?? null;
      row.check_out_at = payload.check_out_at
        ? new Date(payload.check_out_at)
        : row.check_out_at ?? null;
      row.status = payload.status || row.status;
      row.note = payload.note ?? row.note ?? null;
      row.geo_lat = payload.geo_lat ?? row.geo_lat ?? null;
      row.geo_lng = payload.geo_lng ?? row.geo_lng ?? null;
      row.version = Number(row.version || 1) + 1;
    }

    const saved = await this.attendanceRepo.save(row);
    await this.writeLogAndAudit(
      'ATTENDANCE',
      saved.uuid,
      saved.id,
      saved.territory_id || null,
      saved.version,
      'UPSERT',
      user,
      before,
      saved,
      dtoDeviceId(undefined),
    );
    return saved;
  }

  private async writeLogAndAudit(
    entityType: SyncEntityType,
    entityUuid: string,
    entityId: number | null,
    territoryId: number | null,
    version: number,
    operation: SyncOperation,
    user: AuthUser,
    beforeJson: any,
    afterJson: any,
    deviceId: string | null,
  ) {
    await this.syncLogRepo.save(
      this.syncLogRepo.create({
        entity_type: entityType,
        entity_uuid: entityUuid,
        entity_id: entityId,
        territory_id: territoryId,
        version,
        operation,
      }),
    );

    await this.auditRepo.save(
      this.auditRepo.create({
        entity_type: entityType,
        entity_uuid: entityUuid,
        entity_id: entityId,
        action: 'SYNC_MERGE',
        actor_user_id: user.sub,
        actor_role: user.role,
        device_id: deviceId,
        before_json: beforeJson,
        after_json: afterJson,
      }),
    );
  }

  private generateDocNo(prefix: string) {
    return `${prefix}-${Date.now()}`;
  }
}

function dtoDeviceId(_value: unknown): string | null {
  return null;
}