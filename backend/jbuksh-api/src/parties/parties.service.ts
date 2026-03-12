import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { In, Repository } from 'typeorm';
import { PartyEntity } from './party.entity';
import { Role } from '../auth/roles.enum';
import { UserEntity } from '../users/user.entity';
import { InvoiceEntity } from '../invoices/invoice.entity';
import { CollectionEntity } from '../collections/collection.entity';

type AuthUser = {
  sub: number;
  role: Role;
};

type UserScope = {
  territoryIds: number[] | null;
};

@Injectable()
export class PartiesService {
  constructor(
    @InjectRepository(PartyEntity)
    private readonly repo: Repository<PartyEntity>,
    @InjectRepository(UserEntity)
    private readonly usersRepo: Repository<UserEntity>,
    @InjectRepository(InvoiceEntity)
    private readonly invoiceRepo: Repository<InvoiceEntity>,
    @InjectRepository(CollectionEntity)
    private readonly collectionRepo: Repository<CollectionEntity>,
  ) {}

  async create(
    user: AuthUser,
    scope: UserScope,
    input: {
      territory_id?: number;
      party_code: string;
      name: string;
      assigned_mpo_user_id?: number | null;
    },
  ) {
    const territoryIds = scope?.territoryIds ?? [];

    if (!input.party_code?.trim()) {
      throw new BadRequestException('party_code is required');
    }

    if (!input.name?.trim()) {
      throw new BadRequestException('name is required');
    }

    let territoryId: number | null = null;

    // MPO হলে নিজের প্রথম assigned territory auto use করবে
    if (user.role === Role.MPO) {
      if (!territoryIds.length) {
        throw new BadRequestException(
          'No territory assigned to your user. Please contact admin.',
        );
      }
      territoryId = Number(territoryIds[0]);
    } else if (input.territory_id !== undefined && input.territory_id !== null) {
      territoryId = Number(input.territory_id);
    }

    if (!territoryId) {
      throw new BadRequestException('territory_id is required');
    }

    if (
      user.role !== Role.SUPER_ADMIN &&
      !territoryIds.includes(Number(territoryId))
    ) {
      throw new BadRequestException(
        'You are not allowed to create party in this territory',
      );
    }

    const existing = await this.repo.findOne({
      where: { party_code: input.party_code.trim() },
    });

    if (existing) {
      throw new BadRequestException('party_code already exists');
    }

    let assignedMpoUserId: number | null = null;

    if (user.role === Role.MPO) {
      assignedMpoUserId = user.sub;
    } else if (
      input.assigned_mpo_user_id !== undefined &&
      input.assigned_mpo_user_id !== null
    ) {
      const mpoUser = await this.usersRepo.findOne({
        where: { id: Number(input.assigned_mpo_user_id) },
      });

      if (!mpoUser) {
        throw new BadRequestException('Assigned MPO user not found');
      }

      if (mpoUser.role !== Role.MPO) {
        throw new BadRequestException(
          'assigned_mpo_user_id must be an MPO user',
        );
      }

      assignedMpoUserId = Number(input.assigned_mpo_user_id);
    }

    const row = this.repo.create({
      territory_id: Number(territoryId),
      assigned_mpo_user_id: assignedMpoUserId,
      party_code: input.party_code.trim(),
      name: input.name.trim(),
      credit_limit: 0,
      is_active: 1,
      version: 1,
    });

    return this.repo.save(row);
  }

  async list(user: AuthUser, scope: UserScope) {
    const territoryIds = scope?.territoryIds ?? [];

    if (user.role === Role.SUPER_ADMIN) {
      return this.repo.find({ order: { id: 'DESC' as any } });
    }

    if (user.role === Role.MPO) {
      return this.repo.find({
        where: { assigned_mpo_user_id: user.sub, is_active: 1 },
        order: { id: 'DESC' as any },
      });
    }

    if (!territoryIds.length) {
      return [];
    }

    return this.repo.find({
      where: { territory_id: In(territoryIds), is_active: 1 },
      order: { id: 'DESC' as any },
    });
  }

  async details(id: number, user: AuthUser, scope: UserScope) {
    return this.findScopedPartyOrFail(id, user, scope);
  }

  async summary(id: number, user: AuthUser, scope: UserScope) {
    const party = await this.findScopedPartyOrFail(id, user, scope);

    const invoiceAgg = await this.invoiceRepo
      .createQueryBuilder('inv')
      .select('COUNT(*)', 'total_invoices')
      .addSelect(
        "SUM(CASE WHEN inv.status = 'APPROVED' THEN 1 ELSE 0 END)",
        'approved_invoices',
      )
      .addSelect(
        "COALESCE(SUM(CASE WHEN inv.status = 'APPROVED' THEN inv.net_total ELSE 0 END), 0)",
        'total_sales',
      )
      .addSelect(
        "COALESCE(SUM(CASE WHEN inv.status = 'APPROVED' THEN inv.due_amount ELSE 0 END), 0)",
        'outstanding_due',
      )
      .addSelect('MAX(inv.invoice_date)', 'last_invoice_date')
      .where('inv.party_id = :partyId', { partyId: party.id })
      .getRawOne();

    const collectionAgg = await this.collectionRepo
      .createQueryBuilder('col')
      .select(
        "COALESCE(SUM(CASE WHEN col.status = 'APPROVED' THEN col.amount ELSE 0 END), 0)",
        'total_collection',
      )
      .addSelect('MAX(col.collection_date)', 'last_payment_date')
      .where('col.party_id = :partyId', { partyId: party.id })
      .getRawOne();

    const summary = {
      party_id: party.id,
      total_invoices: Number(invoiceAgg?.total_invoices ?? 0),
      approved_invoices: Number(invoiceAgg?.approved_invoices ?? 0),
      total_collection: Number(collectionAgg?.total_collection ?? 0),
      outstanding_due: Number(invoiceAgg?.outstanding_due ?? 0),
      last_invoice_date: invoiceAgg?.last_invoice_date ?? null,
      last_payment_date: collectionAgg?.last_payment_date ?? null,

      // frontend compatibility aliases
      total_sales: Number(invoiceAgg?.total_sales ?? 0),
      total_paid: Number(collectionAgg?.total_collection ?? 0),
      receivable: Number(invoiceAgg?.outstanding_due ?? 0),
      due: Number(invoiceAgg?.outstanding_due ?? 0),
      balance_due: Number(invoiceAgg?.outstanding_due ?? 0),
    };

    return { summary };
  }

  async update(
    id: number,
    user: AuthUser,
    scope: UserScope,
    input: {
      territory_id?: number;
      party_code?: string;
      name?: string;
      credit_limit?: number;
      is_active?: number;
      assigned_mpo_user_id?: number | null;
    },
  ) {
    const territoryIds = scope?.territoryIds ?? [];
    const row = await this.findScopedPartyOrFail(id, user, scope);

    if (input.territory_id !== undefined) {
      if (
        user.role !== Role.SUPER_ADMIN &&
        !territoryIds.includes(Number(input.territory_id))
      ) {
        throw new BadRequestException(
          'You are not allowed to move party to this territory',
        );
      }
      row.territory_id = Number(input.territory_id);
    }

    if (input.party_code !== undefined) {
      const trimmed = input.party_code.trim();
      const sameCode = await this.repo.findOne({ where: { party_code: trimmed } });
      if (sameCode && Number(sameCode.id) !== Number(row.id)) {
        throw new BadRequestException('party_code already exists');
      }
      row.party_code = trimmed;
    }

    if (input.name !== undefined) {
      row.name = input.name.trim();
    }

    if (input.credit_limit !== undefined) {
      row.credit_limit = Number(input.credit_limit || 0);
    }

    if (input.is_active !== undefined) {
      row.is_active = Number(input.is_active);
    }

    if (input.assigned_mpo_user_id !== undefined) {
      if (user.role === Role.MPO) {
        row.assigned_mpo_user_id = user.sub;
      } else if (input.assigned_mpo_user_id === null) {
        row.assigned_mpo_user_id = null;
      } else {
        const mpoUser = await this.usersRepo.findOne({
          where: { id: Number(input.assigned_mpo_user_id) },
        });
        if (!mpoUser) {
          throw new BadRequestException('Assigned MPO user not found');
        }
        if (mpoUser.role !== Role.MPO) {
          throw new BadRequestException(
            'assigned_mpo_user_id must be an MPO user',
          );
        }
        row.assigned_mpo_user_id = Number(input.assigned_mpo_user_id);
      }
    }

    row.version = Number(row.version || 1) + 1;
    await this.repo.save(row);
    return this.findScopedPartyOrFail(id, user, scope);
  }

  private async findScopedPartyOrFail(
    id: number,
    user: AuthUser,
    scope: UserScope,
  ) {
    if (user.role === Role.SUPER_ADMIN) {
      const row = await this.repo.findOne({ where: { id } });
      if (!row) throw new NotFoundException('Party not found');
      return row;
    }

    if (user.role === Role.MPO) {
      const row = await this.repo.findOne({
        where: { id, assigned_mpo_user_id: user.sub },
      });
      if (!row) throw new NotFoundException('Party not found');
      return row;
    }

    const territoryIds = scope?.territoryIds ?? [];
    if (!territoryIds.length) {
      throw new NotFoundException('Party not found');
    }

    const row = await this.repo.findOne({
      where: { id, territory_id: In(territoryIds) },
    });
    if (!row) throw new NotFoundException('Party not found');
    return row;
  }
}