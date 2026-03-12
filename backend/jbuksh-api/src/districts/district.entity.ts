import { Column, Entity, PrimaryGeneratedColumn } from 'typeorm';

@Entity('districts')
export class DistrictEntity {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ type: 'bigint' })
  division_id: number;

  @Column({ type: 'varchar', length: 120 })
  name_bn: string;

  @Column({ type: 'varchar', length: 120 })
  name_en: string;

  @Column({ type: 'varchar', length: 30, unique: true })
  code: string;
}