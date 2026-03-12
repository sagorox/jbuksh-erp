import { Column, Entity, PrimaryGeneratedColumn } from 'typeorm';

@Entity('areas')
export class AreaEntity {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ type: 'bigint' })
  zone_id: number;

  @Column({ type: 'varchar', length: 120 })
  name: string;
}