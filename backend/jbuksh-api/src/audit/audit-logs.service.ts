import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { AuditLogEntity } from './audit-log.entity';

@Injectable()
export class AuditLogsService {
  constructor(
    @InjectRepository(AuditLogEntity)
    private readonly repo: Repository<AuditLogEntity>,
  ) {}

  async list(filters: {
    entity_type?: string;
    entity_id?: number;
    actor_user_id?: number;
    from?: string;
    to?: string;
  }) {
    this.validateDateRange(filters.from, filters.to);

    const qb = this.repo.createQueryBuilder('log').orderBy('log.id', 'DESC');

    if (filters.entity_type?.trim()) {
      qb.andWhere('log.entity_type = :entity_type', {
        entity_type: filters.entity_type.trim(),
      });
    }

    if (filters.entity_id !== undefined) {
      qb.andWhere('log.entity_id = :entity_id', {
        entity_id: Number(filters.entity_id),
      });
    }

    if (filters.actor_user_id !== undefined) {
      qb.andWhere('log.actor_user_id = :actor_user_id', {
        actor_user_id: Number(filters.actor_user_id),
      });
    }

    if (filters.from) {
      qb.andWhere('DATE(log.created_at) >= :from', { from: filters.from });
    }

    if (filters.to) {
      qb.andWhere('DATE(log.created_at) <= :to', { to: filters.to });
    }

    const rows = await qb.getMany();

    return {
      ok: true,
      filters: {
        entity_type: filters.entity_type ?? null,
        entity_id: filters.entity_id ?? null,
        actor_user_id: filters.actor_user_id ?? null,
        from: filters.from ?? null,
        to: filters.to ?? null,
      },
      audit_logs: rows,
    };
  }

  async details(id: number) {
    const row = await this.repo.findOne({ where: { id } });
    if (!row) {
      throw new NotFoundException('Audit log not found');
    }

    return {
      ok: true,
      audit_log: row,
    };
  }

  private validateDateRange(from?: string, to?: string) {
    if (from && to && from > to) {
      throw new BadRequestException('from date cannot be greater than to date');
    }
  }
}