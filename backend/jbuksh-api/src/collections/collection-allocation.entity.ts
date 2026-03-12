import { Column, Entity, PrimaryGeneratedColumn } from 'typeorm';

@Entity('collection_allocations')
export class CollectionAllocationEntity {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ type: 'bigint' })
  collection_id: number;

  @Column({ type: 'bigint' })
  invoice_id: number;

  @Column({ type: 'decimal', precision: 12, scale: 2 })
  applied_amount: number;
}