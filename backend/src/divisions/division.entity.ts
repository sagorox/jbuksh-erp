import { Column, Entity, PrimaryGeneratedColumn } from 'typeorm';

@Entity('divisions')
export class DivisionEntity {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ type: 'varchar', length: 120 })
  name_bn: string;

  @Column({ type: 'varchar', length: 120 })
  name_en: string;

  @Column({ type: 'varchar', length: 30, unique: true })
  code: string;
}