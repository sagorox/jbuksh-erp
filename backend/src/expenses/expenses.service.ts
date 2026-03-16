import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { randomUUID } from 'crypto';
import { ExpenseEntity } from './expense.entity';
import { ExpenseHeadEntity } from './expense-head.entity';
import { Role } from '../auth/roles.enum';
import { ApprovalEntity, ApprovalStatus } from '../approvals/approval.entity';
import { AuditAction, AuditLogEntity } from '../sync/audit-log.entity';

@Injectable()
export class ExpensesService {
  constructor(
    @InjectRepository(ExpenseEntity) private readonly expRepo: Repository<ExpenseEntity>,
    @InjectRepository(ExpenseHeadEntity) private readonly headRepo: Repository<ExpenseHeadEntity>,
    @InjectRepository(ApprovalEntity) private readonly approvalRepo: Repository<ApprovalEntity>,
    @InjectRepository(AuditLogEntity) private readonly auditRepo: Repository<AuditLogEntity>,
  ) {}

  // মেথডগুলোর সুবিধার জন্য `this.expRepo` কে `this.repo` হিসেবে রেফারেন্স করা হয়েছে
  private get repo() {
    return this.expRepo;
  }

  // ---------------- Heads ----------------
  async createHead(name: string) {
    if (!name?.trim()) throw new BadRequestException('name required');
    const head = this.headRepo.create({ name: name.trim(), is_active: 1 });
    const saved = await this.headRepo.save(head);
    return { ok: true, head: saved };
  }

  async listHeads(activeOnly = true) {
    const where: any = {};
    if (activeOnly) where.is_active = 1;
    return this.headRepo.find({ where, order: { name: 'ASC' as any } });
  }

  async toggleHead(id: number, is_active: number) {
    const head = await this.headRepo.findOne({ where: { id } });
    if (!head) throw new NotFoundException('Expense head not found');
    head.is_active = is_active ? 1 : 0;
    await this.headRepo.save(head);
    return { ok: true, head };
  }

  // ---------------- Expenses ----------------
  async createExpense(input: {
    user_id: number;
    territory_id: number;
    expense_date: string;
    head_id: number;
    amount: number;
    note?: string | null;
  }) {
    const head = await this.headRepo.findOne({ where: { id: input.head_id, is_active: 1 } });
    if (!head) throw new BadRequestException('Invalid head_id');

    const exp = this.expRepo.create({
      uuid: randomUUID(),
      user_id: input.user_id,
      territory_id: input.territory_id,
      expense_date: input.expense_date,
      head_id: input.head_id,
      amount: Number(input.amount),
      note: input.note ?? null,
      status: 'DRAFT', // অ্যাপ্রুভাল ফ্লোর জন্য শুরুতে DRAFT রাখা হয়েছে
      version: 1,
    });

    const saved = await this.expRepo.save(exp);
    return { ok: true, expense: saved };
  }

  async listExpenses(params: { from?: string; to?: string; territory_id?: number; user_id?: number }) {
    const qb = this.expRepo.createQueryBuilder('e').orderBy('e.id', 'DESC');

    if (params.from) qb.andWhere('e.expense_date >= :from', { from: params.from });
    if (params.to) qb.andWhere('e.expense_date <= :to', { to: params.to });
    if (params.territory_id) qb.andWhere('e.territory_id = :tid', { tid: params.territory_id });
    if (params.user_id) qb.andWhere('e.user_id = :uid', { uid: params.user_id });

    return qb.getMany();
  }

  // ✅ নতুন মেথড: submit
  async submit(
    id: number,
    user: { sub: number; role: Role },
    scope: { territoryIds: number[] | null },
  ) {
    const expense = await this.findScopedExpenseOrFail(id, user, scope);

    if (!['SUBMITTED', 'DECLINED', 'DRAFT'].includes(String(expense.status))) {
      throw new BadRequestException(
        'Only submitted/declined/draft expense can go for approval',
      );
    }

    const before = { ...expense };

    expense.status = 'PENDING_APPROVAL';
    expense.version = Number(expense.version || 1) + 1;
    await this.repo.save(expense);

    await this.approvalRepo.save(
      this.approvalRepo.create({
        entity_type: 'EXPENSE',
        entity_id: expense.id,
        status: 'PENDING',
        requested_by: user.sub,
        requested_at: new Date(),
      }),
    );

    await this.writeAudit('EXPENSE', expense.id, 'UPDATE', user, before, expense);

    return expense;
  }

  // ✅ নতুন মেথড: markApproved
  async markApproved(
    id: number,
    user: { sub: number; role: Role },
    scope: { territoryIds: number[] | null },
  ) {
    const expense = await this.findScopedExpenseOrFail(id, user, scope);

    if (String(expense.status) !== 'PENDING_APPROVAL') {
      throw new BadRequestException('Expense is not pending approval');
    }

    const before = { ...expense };

    expense.status = 'APPROVED';
    expense.version = Number(expense.version || 1) + 1;
    await this.repo.save(expense);

    await this.writeAudit('EXPENSE', expense.id, 'APPROVE', user, before, expense);

    return expense;
  }

  // ✅ নতুন মেথড: markDeclined
  async markDeclined(
    id: number,
    user: { sub: number; role: Role },
    scope: { territoryIds: number[] | null },
    reason: string,
  ) {
    const expense = await this.findScopedExpenseOrFail(id, user, scope);

    if (String(expense.status) !== 'PENDING_APPROVAL') {
      throw new BadRequestException('Expense is not pending approval');
    }

    const before = { ...expense };

    expense.status = 'DECLINED';
    expense.note = reason || expense.note || null;
    expense.version = Number(expense.version || 1) + 1;
    await this.repo.save(expense);

    await this.writeAudit('EXPENSE', expense.id, 'DECLINE', user, before, expense);

    return expense;
  }

  // ✅ হেল্পার মেথড: findScopedExpenseOrFail
  private async findScopedExpenseOrFail(
    id: number,
    user: { sub: number; role: Role },
    scope: { territoryIds: number[] | null },
  ) {
    const qb = this.repo.createQueryBuilder('expense').where('expense.id = :id', {
      id,
    });

    if (user.role === Role.SUPER_ADMIN) {
      const row = await qb.getOne();
      if (!row) throw new NotFoundException('Expense not found');
      return row;
    }

    if (user.role === Role.MPO) {
      qb.andWhere('expense.user_id = :userId', { userId: user.sub });
      const row = await qb.getOne();
      if (!row) throw new NotFoundException('Expense not found');
      return row;
    }

    const territoryIds = scope?.territoryIds ?? [];
    if (!territoryIds.length) {
      throw new NotFoundException('Expense not found');
    }

    qb.andWhere('expense.territory_id IN (:...territoryIds)', { territoryIds });

    const row = await qb.getOne();
    if (!row) throw new NotFoundException('Expense not found');
    return row;
  }

  // অডিট লগ রাইট করার হেল্পার মেথড
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
        action: action,
        actor_user_id: user.sub,
        actor_role: user.role,
        before_json: before,
        after_json: after,
      }),
    );
  }
}