import { Column, Entity, PrimaryGeneratedColumn } from 'typeorm';

@Entity('parties')
export class PartyEntity {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ type: 'varchar', length: 36, unique: true, default: () => 'UUID()' })
  uuid: string;

  @Column({ type: 'bigint' })
  territory_id: number;

  @Column({ type: 'bigint', nullable: true })
  assigned_mpo_user_id: number | null;

  @Column({ type: 'varchar', length: 40, unique: true })
  party_code: string;

  @Column({ type: 'varchar', length: 180 })
  name: string;

  @Column({ type: 'decimal', precision: 12, scale: 2, default: 0 })
  credit_limit: number;

  @Column({ type: 'tinyint', default: 1 })
  is_active: number;

  @Column({ type: 'int', default: 1 })
  version: number;
}
