import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { CollectionEntity } from './collection.entity';
import { CollectionAllocationEntity } from './collection-allocation.entity';
import { InvoiceEntity } from '../invoices/invoice.entity';
import { ApprovalEntity } from '../approvals/approval.entity';
import { Role } from '../auth/roles.enum';
import { AuditAction, AuditLogEntity } from '../sync/audit-log.entity';

@Injectable()
export class CollectionsService {
  constructor(
    @InjectRepository(CollectionEntity) private readonly colRepo: Repository<CollectionEntity>,
    @InjectRepository(CollectionAllocationEntity) private readonly allocRepo: Repository<CollectionAllocationEntity>,
    @InjectRepository(InvoiceEntity) private readonly invRepo: Repository<InvoiceEntity>,
    @InjectRepository(ApprovalEntity) private readonly approvalRepo: Repository<ApprovalEntity>,
    @InjectRepository(AuditLogEntity) private readonly auditRepo: Repository<AuditLogEntity>,
  ) {}

  async nextCollectionNo() {
    const count = await this.colRepo.count();
    return `COL-${String(count + 1).padStart(6, '0')}`;
  }

  async create(
    user: { sub: number; role: Role },
    scope: { territoryIds: number[] | null },
    input: {
      territory_id?: number;
      party_id: number;
      collection_date: string;
      method: 'CASH' | 'BANK' | 'MFS';
      amount: number;
      reference_no?: string | null;
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
        'You are not allowed to create collection in this territory',
      );
    }

    const collectionNo = await this.nextCollectionNo();

    const col = this.colRepo.create({
      collection_no: collectionNo,
      mpo_user_id: user.sub,
      territory_id: Number(territoryId),
      party_id: input.party_id,
      collection_date: input.collection_date,
      method: input.method,
      amount: Number(input.amount),
      reference_no: input.reference_no ?? null,
      status: 'DRAFT',
      unused_amount: Number(Number(input.amount).toFixed(2)) as any,
      version: 1,
    });

    const saved = await this.colRepo.save(col);
    return { ok: true, collection: saved };
  }

  async submit(
    id: number,
    user: { sub: number; role: Role },
    scope: { territoryIds: number[] | null },
  ) {
    const collection = await this.findScopedCollectionOrFail(id, user, scope);

    if (!['SUBMITTED', 'DECLINED', 'DRAFT', 'APPROVED'].includes(String(collection.status))) {
      throw new BadRequestException(
        'Only submitted/declined/draft collection can go for approval',
      );
    }

    const before = { ...collection };

    collection.status = 'PENDING_APPROVAL';
    collection.version = Number(collection.version || 1) + 1;
    await this.colRepo.save(collection);

    await this.approvalRepo.save(
      this.approvalRepo.create({
        entity_type: 'COLLECTION',
        entity_id: collection.id,
        status: 'PENDING',
        requested_by: user.sub,
        requested_at: new Date(),
      }),
    );

    await this.writeAudit(
      'COLLECTION',
      collection.id,
      'UPDATE',
      user,
      before,
      collection,
    );

    return collection;
  }

  async markApproved(
    id: number,
    user: { sub: number; role: Role },
    scope: { territoryIds: number[] | null },
  ) {
    const collection = await this.findScopedCollectionOrFail(id, user, scope);

    if (String(collection.status) !== 'PENDING_APPROVAL') {
      throw new BadRequestException('Collection is not pending approval');
    }

    const before = { ...collection };

    collection.status = 'APPROVED';
    collection.version = Number(collection.version || 1) + 1;
    await this.colRepo.save(collection);

    await this.writeAudit(
      'COLLECTION',
      collection.id,
      'APPROVE',
      user,
      before,
      collection,
    );

    return collection;
  }

  async markDeclined(
    id: number,
    user: { sub: number; role: Role },
    scope: { territoryIds: number[] | null },
    reason: string,
  ) {
    const collection = await this.findScopedCollectionOrFail(id, user, scope);

    if (String(collection.status) !== 'PENDING_APPROVAL') {
      throw new BadRequestException('Collection is not pending approval');
    }

    const before = { ...collection };

    collection.status = 'DECLINED';
    collection.reference_no = reason || collection.reference_no || null;
    collection.version = Number(collection.version || 1) + 1;
    await this.colRepo.save(collection);

    await this.writeAudit(
      'COLLECTION',
      collection.id,
      'DECLINE',
      user,
      before,
      collection,
    );

    return collection;
  }

  private async findScopedCollectionOrFail(
    id: number,
    user: { sub: number; role: Role },
    scope: { territoryIds: number[] | null },
  ) {
    const qb = this.colRepo
      .createQueryBuilder('collection')
      .where('collection.id = :id', { id });

    if (user.role === Role.SUPER_ADMIN) {
      const row = await qb.getOne();
      if (!row) throw new NotFoundException('Collection not found');
      return row;
    }

    if (user.role === Role.MPO) {
      qb.andWhere('collection.mpo_user_id = :userId', { userId: user.sub });
      const row = await qb.getOne();
      if (!row) throw new NotFoundException('Collection not found');
      return row;
    }

    const territoryIds = scope?.territoryIds ?? [];
    if (!territoryIds.length) {
      throw new NotFoundException('Collection not found');
    }

    qb.andWhere('collection.territory_id IN (:...territoryIds)', { territoryIds });

    const row = await qb.getOne();
    if (!row) throw new NotFoundException('Collection not found');
    return row;
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
        entity_id: entityId,
        action,
        actor_user_id: user.sub,
        actor_role: user.role,
        before_json: before,
        after_json: after,
      }),
    );
  }

  async allocate(
    collection_id: number,
    allocations: Array<{ invoice_id: number; applied_amount: number }>,
    user: { sub: number; role: Role },
    scope: { territoryIds: number[] | null },
  ) {
    const col = await this.findScopedCollectionOrFail(collection_id, user, scope);
    if (col.status !== 'APPROVED') {
      throw new BadRequestException('Only APPROVED collection can allocate');
    }

    await this.allocRepo.delete({ collection_id });

    const totalApply = allocations.reduce(
      (sum, a) => sum + Number(a.applied_amount),
      0,
    );

    if (totalApply > Number(col.amount)) {
      throw new BadRequestException('Applied amount exceeds collection amount');
    }

    const rows: CollectionAllocationEntity[] = [];

    for (const a of allocations) {
      const inv = await this.invRepo.findOne({
        where: { id: Number(a.invoice_id) },
      });

      if (!inv) {
        throw new NotFoundException(`Invoice not found: ${a.invoice_id}`);
      }

      if (Number(inv.party_id) !== Number(col.party_id)) {
        throw new BadRequestException('Invoice does not belong to the same party');
      }

      if (Number(inv.territory_id) !== Number(col.territory_id)) {
        throw new BadRequestException('Invoice territory mismatch');
      }

      rows.push(
        this.allocRepo.create({
          collection_id,
          invoice_id: Number(a.invoice_id),
          applied_amount: Number(a.applied_amount),
        }),
      );
    }

    await this.allocRepo.save(rows);

    for (const a of rows) {
      const inv = await this.invRepo.findOne({
        where: { id: Number(a.invoice_id) },
      });

      if (!inv) continue;

      const nextDue = Number(inv.due_amount) - Number(a.applied_amount);
      inv.due_amount = (nextDue < 0 ? 0 : Number(nextDue.toFixed(2))) as any;

      const received = Number(inv.net_total) - Number(inv.due_amount);
      inv.received_amount = (received < 0 ? 0 : Number(received.toFixed(2))) as any;

      await this.invRepo.save(inv);
    }

    col.unused_amount = Number(
      (Number(col.amount) - totalApply).toFixed(2),
    ) as any;
    await this.colRepo.save(col);

    return {
      ok: true,
      collection_id,
      unused_amount: Number(col.unused_amount),
      allocations: rows,
    };
  }

  async list(
    user: { sub: number; role: Role },
    scope: { territoryIds: number[] | null },
    status?: string,
    party_id?: number,
  ) {
    const qb = this.colRepo
      .createQueryBuilder('collection')
      .orderBy('collection.id', 'DESC');

    if (status) {
      qb.andWhere('collection.status = :status', { status });
    }

    if (party_id !== undefined) {
      qb.andWhere('collection.party_id = :party_id', { party_id });
    }

    if (user.role === Role.SUPER_ADMIN) {
      return qb.getMany();
    }

    if (user.role === Role.MPO) {
      qb.andWhere('collection.mpo_user_id = :userId', { userId: user.sub });
      return qb.getMany();
    }

    const territoryIds = scope?.territoryIds ?? [];
    if (!territoryIds.length) return [];

    qb.andWhere('collection.territory_id IN (:...territoryIds)', {
      territoryIds,
    });

    return qb.getMany();
  }
}