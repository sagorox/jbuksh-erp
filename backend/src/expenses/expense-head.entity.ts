import { Column, Entity, Index, PrimaryGeneratedColumn } from 'typeorm';

@Entity('expense_heads')
export class ExpenseHeadEntity {
  @PrimaryGeneratedColumn()
  id: number;

  @Index({ unique: true })
  @Column({ type: 'varchar', length: 120 })
  name: string;

  @Column({ type: 'tinyint', default: 1 })
  is_active: number;
}