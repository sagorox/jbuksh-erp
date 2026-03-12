import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm';
import { PartyEntity } from '../parties/party.entity'; //

export type InvoiceStatus =
  | 'DRAFT'
  | 'SUBMITTED'
  | 'PENDING_APPROVAL'
  | 'APPROVED'
  | 'DECLINED'
  | 'PRINTED'
  | 'CANCELLED'; //

@Entity('invoices')
export class InvoiceEntity {
  @PrimaryGeneratedColumn()
  id: number; //

  @Index({ unique: true })
  @Column({ type: 'varchar', length: 36, default: () => 'UUID()' })
  uuid: string;

  @Index({ unique: true })
  @Column({ type: 'varchar', length: 40 })
  invoice_no: string; //

  @Column({ type: 'bigint' })
  mpo_user_id: number; //

  @Column({ type: 'bigint' })
  territory_id: number; //

  @Column({ type: 'bigint' })
  party_id: number; //

  // ✅ Party Entity-এর সাথে রিলেশন যুক্ত করা হয়েছে
  @ManyToOne(() => PartyEntity, { eager: false })
  @JoinColumn({ name: 'party_id' })
  party: PartyEntity; //

  @Column({ type: 'date' })
  invoice_date: string; //

  @Column({ type: 'time' })
  invoice_time: string; //

  @Column({ type: 'varchar', length: 30, default: 'DRAFT' })
  status: InvoiceStatus; //

  @Column({ type: 'decimal', precision: 12, scale: 2, default: 0 })
  subtotal: number; //

  @Column({ type: 'decimal', precision: 6, scale: 2, default: 0 })
  discount_percent: number; //

  @Column({ type: 'decimal', precision: 12, scale: 2, default: 0 })
  discount_amount: number; //

  @Column({ type: 'decimal', precision: 12, scale: 2, default: 0 })
  net_total: number; //

  @Column({ type: 'decimal', precision: 12, scale: 2, default: 0 })
  received_amount: number; //

  @Column({ type: 'decimal', precision: 12, scale: 2, default: 0 })
  due_amount: number; //

  @Column({ type: 'text', nullable: true })
  remarks: string | null; //

  @Column({ type: 'varchar', length: 255, nullable: true })
  pdf_url: string | null; //

  // Offline items payload (until full invoice_items tables are added)
  @Column({ type: 'longtext', nullable: true })
  items_json: string | null;

  @Column({ type: 'int', default: 1 })
  version: number;

  @CreateDateColumn({ type: 'datetime' })
  created_at: Date;

  @UpdateDateColumn({ type: 'datetime' })
  updated_at: Date;
}