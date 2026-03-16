import { Column, Entity, Index, PrimaryGeneratedColumn, UpdateDateColumn } from 'typeorm';

export type AttendanceStatus = 'PENDING' | 'APPROVED' | 'DECLINED';

@Entity('attendance')
@Index(['user_id', 'att_date'], { unique: true })
export class AttendanceEntity {
  @PrimaryGeneratedColumn()
  id: number;

  @Index({ unique: true })
  @Column({ type: 'varchar', length: 36, default: () => 'UUID()' })
  uuid: string;

  @Column({ type: 'bigint' })
  user_id: number;

  @Column({ type: 'bigint', nullable: true })
  territory_id: number | null;

  @Column({ type: 'date' })
  att_date: string;

  @Column({ type: 'datetime', nullable: true })
  check_in_at: Date | null;

  @Column({ type: 'datetime', nullable: true })
  check_out_at: Date | null;

  @Column({ type: 'varchar', length: 20, default: 'PENDING' })
  status: AttendanceStatus;

  @Column({ type: 'text', nullable: true })
  note: string | null;

  @Column({ type: 'decimal', precision: 10, scale: 7, nullable: true })
  geo_lat: number | null;

  @Column({ type: 'decimal', precision: 10, scale: 7, nullable: true })
  geo_lng: number | null;

  @Column({ type: 'int', default: 1 })
  version: number;

  @UpdateDateColumn({ type: 'datetime' })
  updated_at: Date;
}