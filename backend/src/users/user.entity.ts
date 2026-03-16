import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm';
import { Role } from '../auth/roles.enum';

@Entity('users')
export class UserEntity {
  @PrimaryGeneratedColumn()
  id: number;

  @Index({ unique: true })
  @Column({ type: 'varchar', length: 20 })
  phone: string;

  @Column({ type: 'varchar', length: 120 })
  full_name: string;

  @Column({ type: 'varchar', length: 255 })
  password_hash: string;

  @Column({ type: 'enum', enum: Role, default: Role.MPO })
  role: Role;

  @Column({ type: 'bigint' })
  division_id: number;

  @Column({ type: 'bigint' })
  district_id: number;

  @Column({ type: 'bigint' })
  zone_id: number;

  @Column({ type: 'bigint' })
  area_id: number;

  @Column({ type: 'bigint' })
  territory_id: number;

  @Column({ type: 'tinyint', default: 1 })
  is_active: number;

  @CreateDateColumn()
  created_at: Date;

  @UpdateDateColumn()
  updated_at: Date;
}