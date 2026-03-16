import { Column, CreateDateColumn, Entity, Index, PrimaryGeneratedColumn, UpdateDateColumn } from 'typeorm';

export type DeliveryStatus = 'PACKED' | 'DISPATCHED' | 'DELIVERED';

@Entity('deliveries')
export class DeliveryEntity {
  @PrimaryGeneratedColumn()
  id: number;

  @Index({ unique: true })
  @Column({ type: 'varchar', length: 36, default: () => 'UUID()' })
  uuid: string;

  @Index({ unique: true })
  @Column({ type: 'varchar', length: 40 })
  delivery_no: string;

  @Column({ type: 'bigint', nullable: true })
  warehouse_id: number | null;

  @Column({ type: 'bigint' })
  invoice_id: number;

  @Column({ type: 'varchar', length: 20, default: 'PACKED' })
  status: DeliveryStatus;

  @Column({ type: 'datetime', nullable: true })
  packed_at: Date | null;

  @Column({ type: 'datetime', nullable: true })
  dispatched_at: Date | null;

  @Column({ type: 'datetime', nullable: true })
  delivered_at: Date | null;

  @Column({ type: 'bigint', nullable: true })
  confirmed_by: number | null;

  @Column({ type: 'int', default: 1 })
  version: number;

  @CreateDateColumn({ type: 'datetime' })
  created_at: Date;

  @UpdateDateColumn({ type: 'datetime' })
  updated_at: Date;
}