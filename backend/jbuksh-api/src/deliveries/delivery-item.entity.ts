import { Column, Entity, PrimaryGeneratedColumn } from 'typeorm';

@Entity('delivery_items')
export class DeliveryItemEntity {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ type: 'bigint' })
  delivery_id: number;

  @Column({ type: 'bigint' })
  product_id: number;

  // qty includes sale qty; free qty আলাদা কলাম না রেখে total_qty হিসেবে রাখছি (simple)
  @Column({ type: 'decimal', precision: 12, scale: 2, default: 0 })
  qty: number;
}