import { Column, Entity, PrimaryGeneratedColumn } from 'typeorm';

@Entity('user_territories')
export class UserTerritoryEntity {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ type: 'bigint' })
  user_id: number;

  @Column({ type: 'bigint' })
  territory_id: number;

  @Column({ type: 'tinyint', default: 0 })
  is_primary: number;

  @Column({ type: 'datetime', nullable: true })
  assigned_at: Date | null;
}