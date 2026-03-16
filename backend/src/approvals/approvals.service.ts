import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Role } from '../auth/roles.enum';
import { ApprovalEntity, ApprovalStatus } from './approval.entity';
import { InvoiceEntity } from '../invoices/invoice.entity';
import { CollectionEntity } from '../collections/collection.entity';
import { ExpenseEntity } from '../expenses/expense.entity';
import { NotificationEntity } from '../notifications/notification.entity';
import { AuditAction, AuditLogEntity } from '../sync/audit-log.entity';
import { InvoicesService } from '../invoices/invoices.service';
import { CollectionsService } from '../collections/collections.service';
import { ExpensesService } from '../expenses/expenses.service';

type AuthUser = {
  sub: number;
  role: Role;
};

type UserScope = {
  territoryIds: number[] | null;
};

@Injectable()
export class ApprovalsService {
  constructor(
    @InjectRepository(ApprovalEntity)
    private readonly approvalRepo: Repository<ApprovalEntity>,
    @InjectRepository(InvoiceEntity)
    private readonly invoiceRepo: Repository<InvoiceEntity>,
    @InjectRepository(CollectionEntity)
    private readonly collectionRepo: Repository<CollectionEntity>,
    @InjectRepository(ExpenseEntity)
    private readonly expenseRepo: Repository<ExpenseEntity>,
    @InjectRepository(NotificationEntity)
    private readonly notifRepo: Repository<NotificationEntity>,
    @InjectRepository(AuditLogEntity)
    private readonly auditRepo: Repository<AuditLogEntity>,
    private readonly invoicesService: InvoicesService,
    private readonly collectionsService: CollectionsService,
    private readonly expensesService: ExpensesService,
  ) {}

  async list(
    user: AuthUser,
    scope: UserScope,
    status?: string,
    entityType?: string,
  ) {
    this.assertCanApprove(user);

    const qb = this.approvalRepo
      .createQueryBuilder('approval')
      .orderBy('approval.id', 'DESC');

    if (status) {
      qb.andWhere('approval.status = :status', { status });
    }

    if (entityType) {
      qb.andWhere('approval.entity_type = :entityType', { entityType });
    }

    if (user.role === Role.SUPER_ADMIN) {
      return qb.getMany();
    }

    const territoryIds = scope?.territoryIds ?? [];
    if (!territoryIds.length) {
      return [];
    }

    const rows = await qb.getMany();
    const result: ApprovalEntity[] = [];

    for (const row of rows) {
      const ok = await this.isApprovalVisible(row, territoryIds);
      if (ok) result.push(row);
    }

    return result;
  }

  async approve(
    id: number,
    user: AuthUser,
    scope: UserScope,
    reason: string | null,
  ) {
    this.assertCanApprove(user);

    const approval = await this.approvalRepo.findOne({ where: { id } });
    if (!approval) {
      throw new NotFoundException('Approval not found');
    }

    if (approval.status !== 'PENDING') {
      throw new BadRequestException('Approval already processed');
    }

    if (user.role !== Role.SUPER_ADMIN) {
      const territoryIds = scope?.territoryIds ?? [];
      const visible = await this.isApprovalVisible(approval, territoryIds);
      if (!visible) {
        throw new NotFoundException('Approval not found');
      }
    }

    if (approval.entity_type === 'INVOICE') {
      const invoice = await this.invoicesService.markApproved(
        approval.entity_id,
        user,
        scope,
      );

      approval.status = 'APPROVED';
      approval.action_by = user.sub;
      approval.action_at = new Date();
      approval.reason = reason || null;
      await this.approvalRepo.save(approval);

      await this.notifRepo.save(
        this.notifRepo.create({
          user_id: invoice.mpo_user_id,
          title: 'Invoice approved',
          body: `Invoice ${invoice.invoice_no} approved`,
          type: 'APPROVAL',
          ref_type: 'INVOICE',
          ref_id: invoice.id,
          is_read: 0,
        }),
      );

      await this.writeAudit('APPROVAL', approval.id, 'APPROVE', user, null, approval);
      return approval;
    }

    if (approval.entity_type === 'COLLECTION') {
      const collection = await this.collectionsService.markApproved(
        approval.entity_id,
        user,
        scope,
      );

      approval.status = 'APPROVED';
      approval.action_by = user.sub;
      approval.action_at = new Date();
      approval.reason = reason || null;
      await this.approvalRepo.save(approval);

      await this.notifRepo.save(
        this.notifRepo.create({
          user_id: collection.mpo_user_id,
          title: 'Collection approved',
          body: `Collection ${collection.collection_no} approved`,
          type: 'APPROVAL',
          ref_type: 'COLLECTION',
          ref_id: collection.id,
          is_read: 0,
        }),
      );

      await this.writeAudit('APPROVAL', approval.id, 'APPROVE', user, null, approval);
      return approval;
    }

    if (approval.entity_type === 'EXPENSE') {
      const expense = await this.expensesService.markApproved(
        approval.entity_id,
        user,
        scope,
      );

      approval.status = 'APPROVED';
      approval.action_by = user.sub;
      approval.action_at = new Date();
      approval.reason = reason || null;
      await this.approvalRepo.save(approval);

      await this.notifRepo.save(
        this.notifRepo.create({
          user_id: expense.user_id,
          title: 'Expense approved',
          body: `Expense #${expense.id} approved`,
          type: 'APPROVAL',
          ref_type: 'EXPENSE',
          ref_id: expense.id,
          is_read: 0,
        }),
      );

      await this.writeAudit('APPROVAL', approval.id, 'APPROVE', user, null, approval);
      return approval;
    }

    throw new BadRequestException('Unsupported approval entity');
  }

  async decline(
    id: number,
    user: AuthUser,
    scope: UserScope,
    reason: string | null,
  ) {
    this.assertCanApprove(user);

    if (!reason || !String(reason).trim()) {
      throw new BadRequestException('Decline reason is required');
    }

    const approval = await this.approvalRepo.findOne({ where: { id } });
    if (!approval) {
      throw new NotFoundException('Approval not found');
    }

    if (approval.status !== 'PENDING') {
      throw new BadRequestException('Approval already processed');
    }

    if (user.role !== Role.SUPER_ADMIN) {
      const territoryIds = scope?.territoryIds ?? [];
      const visible = await this.isApprovalVisible(approval, territoryIds);
      if (!visible) {
        throw new NotFoundException('Approval not found');
      }
    }

    if (approval.entity_type === 'INVOICE') {
      const invoice = await this.invoicesService.markDeclined(
        approval.entity_id,
        user,
        scope,
        reason,
      );

      approval.status = 'DECLINED';
      approval.action_by = user.sub;
      approval.action_at = new Date();
      approval.reason = reason;
      await this.approvalRepo.save(approval);

      await this.notifRepo.save(
        this.notifRepo.create({
          user_id: invoice.mpo_user_id,
          title: 'Invoice declined',
          body: `Invoice ${invoice.invoice_no} declined. Reason: ${reason}`,
          type: 'APPROVAL',
          ref_type: 'INVOICE',
          ref_id: invoice.id,
          is_read: 0,
        }),
      );

      await this.writeAudit('APPROVAL', approval.id, 'DECLINE', user, null, approval);
      return approval;
    }

    if (approval.entity_type === 'COLLECTION') {
      const collection = await this.collectionsService.markDeclined(
        approval.entity_id,
        user,
        scope,
        reason,
      );

      approval.status = 'DECLINED';
      approval.action_by = user.sub;
      approval.action_at = new Date();
      approval.reason = reason;
      await this.approvalRepo.save(approval);

      await this.notifRepo.save(
        this.notifRepo.create({
          user_id: collection.mpo_user_id,
          title: 'Collection declined',
          body: `Collection ${collection.collection_no} declined. Reason: ${reason}`,
          type: 'APPROVAL',
          ref_type: 'COLLECTION',
          ref_id: collection.id,
          is_read: 0,
        }),
      );

      await this.writeAudit('APPROVAL', approval.id, 'DECLINE', user, null, approval);
      return approval;
    }

    if (approval.entity_type === 'EXPENSE') {
      const expense = await this.expensesService.markDeclined(
        approval.entity_id,
        user,
        scope,
        reason,
      );

      approval.status = 'DECLINED';
      approval.action_by = user.sub;
      approval.action_at = new Date();
      approval.reason = reason;
      await this.approvalRepo.save(approval);

      await this.notifRepo.save(
        this.notifRepo.create({
          user_id: expense.user_id,
          title: 'Expense declined',
          body: `Expense #${expense.id} declined. Reason: ${reason}`,
          type: 'APPROVAL',
          ref_type: 'EXPENSE',
          ref_id: expense.id,
          is_read: 0,
        }),
      );

      await this.writeAudit('APPROVAL', approval.id, 'DECLINE', user, null, approval);
      return approval;
    }

    throw new BadRequestException('Unsupported approval entity');
  }

  private assertCanApprove(user: AuthUser) {
    const allowed = [Role.SUPER_ADMIN, Role.RSM, Role.SALES_DEPT, Role.ACCOUNTING];
    if (!allowed.includes(user.role)) {
      throw new BadRequestException('You are not allowed to approve');
    }
  }

  private async isApprovalVisible(row: ApprovalEntity, territoryIds: number[]) {
    if (!territoryIds.length) return false;

    if (row.entity_type === 'INVOICE') {
      const invoice = await this.invoiceRepo.findOne({ where: { id: row.entity_id } });
      return !!invoice && territoryIds.includes(Number(invoice.territory_id));
    }

    if (row.entity_type === 'COLLECTION') {
      const collection = await this.collectionRepo.findOne({ where: { id: row.entity_id } });
      return !!collection && territoryIds.includes(Number(collection.territory_id));
    }

    if (row.entity_type === 'EXPENSE') {
      const expense = await this.expenseRepo.findOne({ where: { id: row.entity_id } });
      return !!expense && territoryIds.includes(Number(expense.territory_id));
    }

    return false;
  }

  private async writeAudit(
    entityType: string,
    entityId: number,
    action: AuditAction,
    user: AuthUser,
    beforeJson: any,
    afterJson: any,
  ) {
    try {
      await this.auditRepo.save(
        this.auditRepo.create({
          entity_type: entityType,
          entity_id: entityId,
          action,
          actor_user_id: user.sub,
          actor_role: user.role,
          before_json: beforeJson,
          after_json: afterJson,
        }),
      );
    } catch {
      // ignore audit failure
    }
  }
}
