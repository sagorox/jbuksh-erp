import { Column, Entity, PrimaryGeneratedColumn } from 'typeorm';

@Entity('work_schedules')
export class WorkScheduleEntity {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ type: 'varchar', length: 120 })
  name: string;

  @Column({ type: 'date' })
  start_date: string;

  @Column({ type: 'date' })
  end_date: string;

  @Column({ type: 'bigint' })
  created_by: number;
}