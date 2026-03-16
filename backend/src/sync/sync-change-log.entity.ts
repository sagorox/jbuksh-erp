import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  PrimaryGeneratedColumn,
} from 'typeorm';

export type SyncEntityType =
  | 'PARTY'
  | 'PRODUCT'
  | 'INVOICE'
  | 'COLLECTION'
  | 'EXPENSE'
  | 'ATTENDANCE'
  | 'DELIVERY';

export type SyncOperation = 'UPSERT' | 'DELETE';

@Entity('sync_change_log')
@Index(['changed_at'])
@Index(['entity_type', 'entity_uuid', 'version'])
export class SyncChangeLogEntity {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ type: 'varchar', length: 30 })
  entity_type: SyncEntityType;

  @Column({ type: 'varchar', length: 36 })
  entity_uuid: string;

  @Column({ type: 'bigint', nullable: true })
  entity_id: number | null;

  @Column({ type: 'bigint', nullable: true })
  territory_id: number | null;

  @Column({ type: 'int' })
  version: number;

  @Column({ type: 'varchar', length: 10 })
  operation: SyncOperation;

  @CreateDateColumn({ type: 'datetime' })
  changed_at: Date;
}
