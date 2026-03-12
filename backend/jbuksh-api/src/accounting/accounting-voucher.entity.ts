import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm';

export type AccountingVoucherType = 'DEBIT' | 'CREDIT';
export type AccountingVoucherStatus = 'DRAFT' | 'POSTED' | 'CANCELLED';

@Entity('accounting_vouchers')
export class AccountingVoucherEntity {
  @PrimaryGeneratedColumn()
  id: number;

  @Index({ unique: true })
  @Column({ type: 'varchar', length: 36, default: () => 'UUID()' })
  uuid: string;

  @Index({ unique: true })
  @Column({ type: 'varchar', length: 40 })
  voucher_no: string;

  @Column({ type: 'date' })
  voucher_date: string;

  @Column({ type: 'varchar', length: 10 })
  voucher_type: AccountingVoucherType;

  @Column({ type: 'decimal', precision: 12, scale: 2, default: 0 })
  amount: number;

  @Column({ type: 'bigint', nullable: true })
  territory_id: number | null;

  @Column({ type: 'bigint', nullable: true })
  party_id: number | null;

  @Column({ type: 'bigint', nullable: true })
  user_id: number | null;

  @Column({ type: 'varchar', length: 50, nullable: true })
  reference_type: string | null;

  @Column({ type: 'bigint', nullable: true })
  reference_id: number | null;

  @Column({ type: 'text', nullable: true })
  description: string | null;

  @Column({ type: 'varchar', length: 20, default: 'POSTED' })
  status: AccountingVoucherStatus;

  @Column({ type: 'datetime', nullable: true })
  approved_at: Date | null;

  @Column({ type: 'bigint', nullable: true })
  created_by: number | null;

  @Column({ type: 'int', default: 1 })
  version: number;

  @CreateDateColumn({ type: 'datetime' })
  created_at: Date;

  @UpdateDateColumn({ type: 'datetime' })
  updated_at: Date;
}