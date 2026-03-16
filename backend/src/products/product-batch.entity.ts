import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm';

@Entity('product_batches')
export class ProductBatchEntity {
  @PrimaryGeneratedColumn()
  id: number;

  @Index()
  @Column({ type: 'bigint' })
  product_id: number;

  @Column({ type: 'varchar', length: 100 })
  batch_no: string;

  @Column({ type: 'date', nullable: true })
  mfg_date: string | null;

  @Index()
  @Column({ type: 'date', nullable: true })
  exp_date: string | null;

  @Column({ type: 'decimal', precision: 12, scale: 2, default: 0 })
  qty: number;

  @Column({ type: 'decimal', precision: 12, scale: 2, default: 0 })
  mrp: number;

  @Column({ type: 'decimal', precision: 12, scale: 2, default: 0 })
  purchase_price: number;

  @Column({ type: 'int', default: 1 })
  version: number;

  @CreateDateColumn({ type: 'datetime' })
  created_at: Date;

  @UpdateDateColumn({ type: 'datetime' })
  updated_at: Date;
}