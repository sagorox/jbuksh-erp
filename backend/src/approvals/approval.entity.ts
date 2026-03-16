import { Column, Entity, PrimaryGeneratedColumn } from 'typeorm';

export type ApprovalEntityType = 'INVOICE' | 'COLLECTION' | 'EXPENSE' | 'ATTENDANCE';
export type ApprovalStatus = 'PENDING' | 'APPROVED' | 'DECLINED';

@Entity('approvals')
export class ApprovalEntity {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ type: 'varchar', length: 20 })
  entity_type: ApprovalEntityType;

  @Column({ type: 'bigint' })
  entity_id: number;

  @Column({ type: 'varchar', length: 20, default: 'PENDING' })
  status: ApprovalStatus;

  @Column({ type: 'bigint' })
  requested_by: number;

  @Column({ type: 'datetime' })
  requested_at: Date;

  @Column({ type: 'bigint', nullable: true })
  action_by: number | null;

  @Column({ type: 'datetime', nullable: true })
  action_at: Date | null;

  @Column({ type: 'text', nullable: true })
  reason: string | null;
}
