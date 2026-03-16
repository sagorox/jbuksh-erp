import {
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import {
  NotificationEntity,
  NotificationType,
} from './notification.entity';

type AuthUser = { sub?: number; id?: number };

@Injectable()
export class NotificationsService {
  constructor(
    @InjectRepository(NotificationEntity)
    private readonly repo: Repository<NotificationEntity>,
  ) {}

  async list(user: AuthUser) {
    const userId = Number(user?.sub ?? user?.id);

    const rows = await this.repo.find({
      where: { user_id: userId },
      order: { id: 'DESC' as any },
    });

    const unread_count = rows.filter((x) => !Number(x.is_read || 0)).length;

    return {
      ok: true,
      unread_count,
      notifications: rows,
    };
  }

  async markRead(id: number, user: AuthUser) {
    const userId = Number(user?.sub ?? user?.id);

    const row = await this.repo.findOne({
      where: {
        id,
        user_id: userId,
      },
    });

    if (!row) {
      throw new NotFoundException('Notification not found');
    }

    if (!Number(row.is_read || 0)) {
      row.is_read = 1;
      row.read_at = new Date();
      await this.repo.save(row);
    }

    return {
      ok: true,
      notification: row,
    };
  }

  async markAllRead(user: AuthUser) {
    const userId = Number(user?.sub ?? user?.id);

    const rows = await this.repo.find({
      where: { user_id: userId },
      order: { id: 'DESC' as any },
    });

    if (!rows.length) {
      return {
        ok: true,
        updated: 0,
      };
    }

    let updated = 0;
    const now = new Date();

    for (const row of rows) {
      if (!Number(row.is_read || 0)) {
        row.is_read = 1;
        row.read_at = now;
        await this.repo.save(row);
        updated += 1;
      }
    }

    return {
      ok: true,
      updated,
    };
  }

  async createForUser(params: {
    user_id: number;
    title: string;
    body: string;
    type?: NotificationType;
    ref_type?: string | null;
    ref_id?: number | null;
  }) {
    const row = this.repo.create({
      user_id: params.user_id,
      title: params.title,
      body: params.body,
      type: params.type || 'SYSTEM',
      ref_type: params.ref_type ?? null,
      ref_id: params.ref_id ?? null,
      is_read: 0,
      read_at: null,
    });

    const saved = await this.repo.save(row);
    return saved;
  }

  async createBulk(
    items: Array<{
      user_id: number;
      title: string;
      body: string;
      type?: NotificationType;
      ref_type?: string | null;
      ref_id?: number | null;
    }>,
  ) {
    if (!items.length) return [];

    const rows = items.map((item) =>
      this.repo.create({
        user_id: item.user_id,
        title: item.title,
        body: item.body,
        type: item.type || 'SYSTEM',
        ref_type: item.ref_type ?? null,
        ref_id: item.ref_id ?? null,
        is_read: 0,
        read_at: null,
      }),
    );

    return this.repo.save(rows);
  }
}