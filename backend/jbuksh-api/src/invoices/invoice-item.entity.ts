import { Column, Entity, PrimaryGeneratedColumn } from 'typeorm';

@Entity('invoice_items')
export class InvoiceItemEntity {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ type: 'bigint' })
  invoice_id: number;

  @Column({ type: 'bigint' })
  product_id: number;

  @Column({ type: 'decimal', precision: 12, scale: 2 })
  qty: number;

  @Column({ type: 'decimal', precision: 12, scale: 2, default: 0 })
  free_qty: number;

  @Column({ type: 'decimal', precision: 12, scale: 2 })
  unit_price: number;

  @Column({ type: 'decimal', precision: 12, scale: 2 })
  line_total: number;
}