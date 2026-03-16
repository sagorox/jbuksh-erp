import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { In, Repository } from 'typeorm';
import { WorkScheduleEntity } from './work-schedule.entity';
import { ScheduleAssignmentEntity } from './schedule-assignment.entity';

@Injectable()
export class SchedulesService {
  constructor(
    @InjectRepository(WorkScheduleEntity) private readonly schRepo: Repository<WorkScheduleEntity>,
    @InjectRepository(ScheduleAssignmentEntity) private readonly assignRepo: Repository<ScheduleAssignmentEntity>,
  ) {}

  async createSchedule(input: { name: string; start_date: string; end_date: string; created_by: number }) {
    if (!input.name) throw new BadRequestException('name required');
    if (!input.start_date || !input.end_date) throw new BadRequestException('start_date/end_date required');
    const row = this.schRepo.create(input);
    return this.schRepo.save(row);
  }

  async assignSchedule(input: { work_schedule_id: number; user_id: number; territory_id?: number | null }) {
    const sch = await this.schRepo.findOne({ where: { id: input.work_schedule_id } });
    if (!sch) throw new NotFoundException('Schedule not found');
    const row = this.assignRepo.create({
      work_schedule_id: input.work_schedule_id,
      user_id: input.user_id,
      territory_id: input.territory_id ?? null,
    });
    await this.assignRepo.delete({ work_schedule_id: input.work_schedule_id, user_id: input.user_id });
    return this.assignRepo.save(row);
  }

  async listSchedules() {
    return this.schRepo.find({ order: { id: 'DESC' as any } });
  }

  async listMySchedules(user_id: number) {
    const assignments = await this.assignRepo.find({ where: { user_id }, order: { id: 'DESC' as any } });
    const ids = assignments.map((a) => a.work_schedule_id);
    const schedules = ids.length ? await this.schRepo.find({ where: { id: In(ids as any) } as any }) : [];
    return assignments.map((a) => ({
      ...a,
      schedule: schedules.find((s) => s.id === a.work_schedule_id) ?? null,
    }));
  }
}
