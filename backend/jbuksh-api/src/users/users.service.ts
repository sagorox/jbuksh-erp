import { Injectable, BadRequestException, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import * as bcrypt from 'bcrypt';
import { In, Repository } from 'typeorm';
import { Role } from '../auth/roles.enum';
import { UserEntity } from './user.entity';

@Injectable()
export class UsersService {
  constructor(
    @InjectRepository(UserEntity)
    private readonly repo: Repository<UserEntity>,
  ) {}

  async findByPhone(phone: string) {
    return this.repo.findOne({ where: { phone } });
  }

  async findById(id: number) {
    return this.repo.findOne({ where: { id } });
  }

  sanitize(user: UserEntity | null) {
    if (!user) return null;
    return {
      id: user.id,
      phone: user.phone,
      full_name: user.full_name,
      role: user.role,
      is_active: user.is_active,
      created_at: user.created_at,
      updated_at: user.updated_at,
    };
  }

  async listUsers(filters: { q?: string; role?: Role; ids?: number[] }) {
    const qb = this.repo.createQueryBuilder('u').orderBy('u.id', 'DESC');

    if (filters.q?.trim()) {
      qb.andWhere('(u.full_name LIKE :q OR u.phone LIKE :q)', { q: `%${filters.q.trim()}%` });
    }
    if (filters.role) {
      qb.andWhere('u.role = :role', { role: filters.role });
    }
    if (filters.ids?.length) {
      qb.andWhere('u.id IN (:...ids)', { ids: filters.ids });
    }

    const rows = await qb.getMany();
    return rows.map((u) => this.sanitize(u));
  }

  async createUser(input: { phone: string; full_name: string; password: string; role: Role }) {
    const exists = await this.findByPhone(input.phone);
    if (exists) throw new BadRequestException('Phone already exists');

    const password_hash = await bcrypt.hash(input.password, 10);

    const user = this.repo.create({
      phone: input.phone,
      full_name: input.full_name,
      password_hash,
      role: input.role,
      is_active: 1,
    });

    const saved = await this.repo.save(user);
    return this.sanitize(saved);
  }

  async updateUser(id: number, input: { full_name?: string; phone?: string; password?: string; role?: Role }) {
    const user = await this.findById(id);
    if (!user) throw new NotFoundException('User not found');

    if (input.phone && input.phone !== user.phone) {
      const exists = await this.findByPhone(input.phone);
      if (exists && exists.id !== user.id) throw new BadRequestException('Phone already exists');
      user.phone = input.phone;
    }

    if (input.full_name?.trim()) user.full_name = input.full_name.trim();
    if (input.role) user.role = input.role;
    if (input.password?.trim()) user.password_hash = await bcrypt.hash(input.password.trim(), 10);

    const saved = await this.repo.save(user);
    return this.sanitize(saved);
  }

  async setStatus(id: number, is_active: number) {
    const user = await this.findById(id);
    if (!user) throw new NotFoundException('User not found');
    user.is_active = is_active ? 1 : 0;
    const saved = await this.repo.save(user);
    return this.sanitize(saved);
  }
}