import { Column, CreateDateColumn, Entity, Index, PrimaryGeneratedColumn, UpdateDateColumn } from 'typeorm';

// ✅ No approval needed for collections (business rule)
// Keep enum values for backward compatibility, but default is APPROVED now.
export type CollectionStatus = 'DRAFT' | 'SUBMITTED' | 'PENDING_APPROVAL' | 'APPROVED' | 'DECLINED';
export type CollectionMethod = 'CASH' | 'BANK' | 'MFS';

@Entity('collections')
export class CollectionEntity {
  @PrimaryGeneratedColumn()
  id: number;

  @Index({ unique: true })
  @Column({ type: 'varchar', length: 36, default: () => 'UUID()' })
  uuid: string;

  @Index({ unique: true })
  @Column({ type: 'varchar', length: 40 })
  collection_no: string;

  @Column({ type: 'bigint' })
  mpo_user_id: number;

  @Column({ type: 'bigint' })
  territory_id: number;

  @Column({ type: 'bigint' })
  party_id: number;

  @Column({ type: 'date' })
  collection_date: string;

  @Column({ type: 'varchar', length: 10, default: 'CASH' })
  method: CollectionMethod;

  @Column({ type: 'decimal', precision: 12, scale: 2 })
  amount: number;

  @Column({ type: 'varchar', length: 80, nullable: true })
  reference_no: string | null;

  // collection can start as draft and move through approval flow
  @Column({ type: 'varchar', length: 30, default: 'APPROVED' })
  status: CollectionStatus;

  // initially full amount is unused; allocate() will reduce it
  @Column({ type: 'decimal', precision: 12, scale: 2, default: 0 })
  unused_amount: number;

  @Column({ type: 'int', default: 1 })
  version: number;

  @CreateDateColumn({ type: 'datetime' })
  created_at: Date;

  @UpdateDateColumn({ type: 'datetime' })
  updated_at: Date;

  // allocations payload (until collection_allocations table is added)
  @Column({ type: 'longtext', nullable: true })
  allocations_json: string | null;
}