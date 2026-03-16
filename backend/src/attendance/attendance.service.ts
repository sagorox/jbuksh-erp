import { BadRequestException, Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { AttendanceEntity } from './attendance.entity';
import { ApprovalEntity } from '../approvals/approval.entity';

function todayISO() {
  const d = new Date();
  // local date in YYYY-MM-DD
  const yyyy = d.getFullYear();
  const mm = String(d.getMonth() + 1).padStart(2, '0');
  const dd = String(d.getDate()).padStart(2, '0');
  return `${yyyy}-${mm}-${dd}`;
}

@Injectable()
export class AttendanceService {
  constructor(
    @InjectRepository(AttendanceEntity) private readonly attRepo: Repository<AttendanceEntity>,
    @InjectRepository(ApprovalEntity) private readonly approvalRepo: Repository<ApprovalEntity>,
  ) {}

  async checkIn(input: {
    user_id: number;
    territory_id?: number | null;
    note?: string | null;
    geo_lat?: number | null;
    geo_lng?: number | null;
  }) {
    const att_date = todayISO();

    let row = await this.attRepo.findOne({ where: { user_id: input.user_id, att_date } });

    if (row?.check_in_at) throw new BadRequestException('Already checked in today');

    if (!row) {
      row = this.attRepo.create({
        user_id: input.user_id,
        territory_id: input.territory_id ?? null,
        att_date,
        check_in_at: new Date(),
        check_out_at: null,
        status: 'PENDING',
        note: input.note ?? null,
        geo_lat: input.geo_lat ?? null,
        geo_lng: input.geo_lng ?? null,
      });
      row = await this.attRepo.save(row);

      // ✅ create approval for attendance
      const approval = this.approvalRepo.create({
        entity_type: 'ATTENDANCE',
        entity_id: row.id,
        status: 'PENDING',
        requested_by: input.user_id,
        requested_at: new Date(),
        action_by: null,
        action_at: null,
        reason: null,
      });
      await this.approvalRepo.save(approval);

      return { ok: true, attendance: row, approval_created: true };
    }

    row.check_in_at = new Date();
    row.status = 'PENDING';
    row.note = input.note ?? row.note;
    row.geo_lat = input.geo_lat ?? row.geo_lat;
    row.geo_lng = input.geo_lng ?? row.geo_lng;

    row = await this.attRepo.save(row);
    return { ok: true, attendance: row, approval_created: false };
  }

  async checkOut(user_id: number) {
    const att_date = todayISO();
    const row = await this.attRepo.findOne({ where: { user_id, att_date } });
    if (!row || !row.check_in_at) throw new BadRequestException('Check-in first');
    if (row.check_out_at) throw new BadRequestException('Already checked out');

    row.check_out_at = new Date();
    row.status = 'PENDING'; // still pending until manager approves
    return { ok: true, attendance: await this.attRepo.save(row) };
  }

  list(user_id?: number, from?: string, to?: string) {
    // simple list (later: filter by date range)
    const where: any = {};
    if (user_id) where.user_id = user_id;
    return this.attRepo.find({ where, order: { id: 'DESC' as any } });
  }
}