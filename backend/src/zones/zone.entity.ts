import { Column, Entity, PrimaryGeneratedColumn } from 'typeorm';

@Entity('zones')
export class ZoneEntity {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ type: 'varchar', length: 120 })
  name: string;
}