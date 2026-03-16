import { Column, Entity, Index, PrimaryGeneratedColumn } from 'typeorm';

@Entity('schedule_assignments')
@Index(['work_schedule_id', 'user_id'], { unique: true })
export class ScheduleAssignmentEntity {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ type: 'bigint' })
  work_schedule_id: number;

  @Column({ type: 'bigint' })
  user_id: number;

  @Column({ type: 'bigint', nullable: true })
  territory_id: number | null;
}