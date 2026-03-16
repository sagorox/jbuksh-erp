import { Column, Entity, Index, PrimaryGeneratedColumn } from 'typeorm';

export type ExpenseStatus = 'DRAFT' | 'SUBMITTED' | 'PENDING_APPROVAL' | 'APPROVED' | 'DECLINED';

@Entity('expenses')
export class ExpenseEntity {
  @PrimaryGeneratedColumn()
  id: number;

  @Index({ unique: true })
  @Column({ type: 'varchar', length: 36 })
  uuid: string;

  @Column({ type: 'bigint' })
  user_id: number;

  @Column({ type: 'bigint' })
  territory_id: number;

  @Column({ type: 'date' })
  expense_date: string;

  @Column({ type: 'bigint' })
  head_id: number;

  @Column({ type: 'decimal', precision: 12, scale: 2 })
  amount: number;

  @Column({ type: 'text', nullable: true })
  note: string | null;

  @Column({ type: 'varchar', length: 20, default: 'DRAFT' })
  status: ExpenseStatus;

  @Column({ type: 'int', default: 1 })
  version: number;
}