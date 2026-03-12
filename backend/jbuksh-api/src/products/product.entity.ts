import { Column, Entity, Index, PrimaryGeneratedColumn } from 'typeorm';

@Entity('products')
export class ProductEntity {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ type: 'varchar', length: 36, unique: true, default: () => 'UUID()' })
  uuid: string;

  @Index({ unique: true })
  @Column({ type: 'varchar', length: 60 })
  sku: string;

  @Column({ type: 'varchar', length: 180 })
  name: string;

  @Column({ type: 'bigint' })
  category_id: number;

  @Column({ type: 'varchar', length: 20, default: 'pcs' })
  unit: string;

  @Column({ type: 'varchar', length: 60, nullable: true })
  potency_tag: string | null;

  @Column({ type: 'decimal', precision: 12, scale: 2, default: 0 })
  purchase_price: number;

  @Column({ type: 'decimal', precision: 12, scale: 2, default: 0 })
  sale_price: number;

  @Column({ type: 'decimal', precision: 12, scale: 2, default: 0 })
  reorder_level: number;

  // basic stock (later: stock_txns দিয়ে calculate করবো)
  @Column({ type: 'decimal', precision: 12, scale: 2, default: 0 })
  in_stock: number;

  @Column({ type: 'tinyint', default: 1 })
  is_active: number;

  @Column({ type: 'int', default: 1 })
  version: number;
}