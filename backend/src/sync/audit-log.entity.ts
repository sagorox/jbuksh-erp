import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  PrimaryGeneratedColumn,
} from 'typeorm';

export type AuditAction =
  | 'CREATE'
  | 'UPDATE'
  | 'DELETE'
  | 'APPROVE'
  | 'DECLINE'
  | 'SYNC_MERGE';

@Entity('audit_logs')
@Index(['entity_type', 'entity_uuid'])
@Index(['created_at'])
export class AuditLogEntity {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ type: 'varchar', length: 40 })
  entity_type: string;

  @Column({ type: 'varchar', length: 36, nullable: true })
  entity_uuid: string | null;

  @Column({ type: 'bigint', nullable: true })
  entity_id: number | null;

  @Column({ type: 'varchar', length: 20 })
  action: AuditAction;

  @Column({ type: 'bigint', nullable: true })
  actor_user_id: number | null;

  @Column({ type: 'varchar', length: 30, nullable: true })
  actor_role: string | null;

  @Column({ type: 'varchar', length: 80, nullable: true })
  device_id: string | null;

  @Column({ type: 'json', nullable: true })
  before_json: any;

  @Column({ type: 'json', nullable: true })
  after_json: any;

  @CreateDateColumn({ type: 'datetime' })
  created_at: Date;
}
