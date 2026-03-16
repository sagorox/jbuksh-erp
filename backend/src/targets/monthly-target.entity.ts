import { Column, Entity, Index, PrimaryGeneratedColumn } from 'typeorm';

@Entity('monthly_targets')
@Index(['user_id', 'territory_id', 'year', 'month'], { unique: true })
export class MonthlyTargetEntity {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ type: 'bigint' })
  user_id: number;

  @Column({ type: 'bigint', nullable: true })
  territory_id: number | null;

  @Column({ type: 'int' })
  year: number;

  @Column({ type: 'int' })
  month: number; // 1-12

  @Column({ type: 'decimal', precision: 12, scale: 2, default: 0 })
  sales_target: number;

  @Column({ type: 'decimal', precision: 12, scale: 2, default: 0 })
  collection_target: number;

  @Column({ type: 'bigint' })
  set_by: number;
}