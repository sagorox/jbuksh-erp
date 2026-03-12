import {
  Column,
  CreateDateColumn,
  Entity,
  PrimaryGeneratedColumn,
} from 'typeorm';

export type NotificationType =
  | 'APPROVAL'
  | 'NOTICE'
  | 'SYSTEM'
  | 'DELIVERY'
  | 'LOW_STOCK';

@Entity('notifications')
export class NotificationEntity {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ type: 'bigint' })
  user_id: number;

  @Column({ type: 'varchar', length: 180 })
  title: string;

  @Column({ type: 'text' })
  body: string;

  @Column({ type: 'varchar', length: 20, default: 'SYSTEM' })
  type: NotificationType;

  @Column({ type: 'varchar', length: 40, nullable: true })
  ref_type: string | null;

  @Column({ type: 'bigint', nullable: true })
  ref_id: number | null;

  @Column({ type: 'tinyint', default: 0 })
  is_read: number;

  @Column({ type: 'datetime', nullable: true })
  read_at: Date | null;

  @CreateDateColumn({ type: 'datetime' })
  created_at: Date;
}