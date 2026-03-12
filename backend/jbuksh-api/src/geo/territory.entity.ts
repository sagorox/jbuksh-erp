import { Column, Entity, PrimaryGeneratedColumn } from 'typeorm';

@Entity('territories')
export class TerritoryEntity {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ type: 'varchar', length: 120 })
  name: string;

  @Column({ type: 'varchar', length: 30, unique: true })
  code: string;

  @Column({ type: 'tinyint', default: 1 })
  is_active: number;
}