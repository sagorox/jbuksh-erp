import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import * as bcrypt from 'bcrypt';
import { Repository } from 'typeorm';
import { Role } from '../auth/roles.enum';
import { UserEntity } from './user.entity';
import { DivisionEntity } from '../divisions/division.entity';
import { DistrictEntity } from '../districts/district.entity';
import { ZoneEntity } from '../zones/zone.entity';
import { AreaEntity } from '../areas/area.entity';
import { TerritoryEntity } from '../geo/territory.entity';
import { UserTerritoryEntity } from '../geo/user-territory.entity';

type UserInput = {
  phone: string;
  full_name: string;
  password: string;
  role: Role;
  division_id: number;
  district_id: number;
  zone_id: number;
  area_id: number;
  territory_id: number;
};

type UserUpdateInput = {
  phone?: string;
  full_name?: string;
  password?: string;
  role?: Role;
  division_id?: number;
  district_id?: number;
  zone_id?: number;
  area_id?: number;
  territory_id?: number;
};

@Injectable()
export class UsersService {
  constructor(
    @InjectRepository(UserEntity)
    private readonly repo: Repository<UserEntity>,
    @InjectRepository(DivisionEntity)
    private readonly divisionRepo: Repository<DivisionEntity>,
    @InjectRepository(DistrictEntity)
    private readonly districtRepo: Repository<DistrictEntity>,
    @InjectRepository(ZoneEntity)
    private readonly zoneRepo: Repository<ZoneEntity>,
    @InjectRepository(AreaEntity)
    private readonly areaRepo: Repository<AreaEntity>,
    @InjectRepository(TerritoryEntity)
    private readonly territoryRepo: Repository<TerritoryEntity>,
    @InjectRepository(UserTerritoryEntity)
    private readonly userTerritoryRepo: Repository<UserTerritoryEntity>,
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
      division_id: Number(user.division_id),
      district_id: Number(user.district_id),
      zone_id: Number(user.zone_id),
      area_id: Number(user.area_id),
      territory_id: Number(user.territory_id),
      is_active: user.is_active,
      created_at: user.created_at,
      updated_at: user.updated_at,
    };
  }

  async listUsers(filters: { q?: string; role?: Role }) {
    const qb = this.repo.createQueryBuilder('u').orderBy('u.id', 'DESC');

    if (filters.q?.trim()) {
      qb.andWhere('(u.full_name LIKE :q OR u.phone LIKE :q)', {
        q: `%${filters.q.trim()}%`,
      });
    }

    if (filters.role) {
      qb.andWhere('u.role = :role', { role: filters.role });
    }

    const rows = await qb.getMany();
    return rows.map((u) => this.sanitize(u));
  }

  private async validateGeoSelection(input: {
    division_id: number;
    district_id: number;
    zone_id: number;
    area_id: number;
    territory_id: number;
  }) {
    const divisionId = Number(input.division_id);
    const districtId = Number(input.district_id);
    const zoneId = Number(input.zone_id);
    const areaId = Number(input.area_id);
    const territoryId = Number(input.territory_id);

    if (!divisionId || !districtId || !zoneId || !areaId || !territoryId) {
      throw new BadRequestException(
        'division_id, district_id, zone_id, area_id, territory_id are required',
      );
    }

    const [division, district, zone, area, territory] = await Promise.all([
      this.divisionRepo.findOne({ where: { id: divisionId } }),
      this.districtRepo.findOne({ where: { id: districtId } }),
      this.zoneRepo.findOne({ where: { id: zoneId } }),
      this.areaRepo.findOne({ where: { id: areaId } }),
      this.territoryRepo.findOne({ where: { id: territoryId } }),
    ]);

    if (!division) throw new BadRequestException('Division not found');
    if (!district) throw new BadRequestException('District not found');
    if (!zone) throw new BadRequestException('Zone not found');
    if (!area) throw new BadRequestException('Area not found');
    if (!territory) throw new BadRequestException('Territory not found');

    if (Number(district.division_id) !== divisionId) {
      throw new BadRequestException(
        'Selected district does not belong to selected division',
      );
    }

    if (Number(area.zone_id) !== zoneId) {
      throw new BadRequestException(
        'Selected area does not belong to selected zone',
      );
    }

    if (Number(territory.area_id) !== areaId) {
      throw new BadRequestException(
        'Selected territory does not belong to selected area',
      );
    }

    if (Number(territory.district_id) !== districtId) {
      throw new BadRequestException(
        'Selected territory does not belong to selected district',
      );
    }

    if (Number(territory.is_active ?? 1) !== 1) {
      throw new BadRequestException('Selected territory is inactive');
    }

    return {
      division_id: divisionId,
      district_id: districtId,
      zone_id: zoneId,
      area_id: areaId,
      territory_id: territoryId,
    };
  }

  async createUser(input: UserInput) {
    if (!input.phone?.trim()) {
      throw new BadRequestException('Phone is required');
    }

    if (!input.full_name?.trim()) {
      throw new BadRequestException('Full name is required');
    }

    if (!input.password?.trim()) {
      throw new BadRequestException('Password is required');
    }

    if (!input.role) {
      throw new BadRequestException('Role is required');
    }

    const exists = await this.findByPhone(input.phone.trim());
    if (exists) {
      throw new BadRequestException('Phone already exists');
    }

    const geo = await this.validateGeoSelection({
      division_id: input.division_id,
      district_id: input.district_id,
      zone_id: input.zone_id,
      area_id: input.area_id,
      territory_id: input.territory_id,
    });

    const password_hash = await bcrypt.hash(input.password.trim(), 10);

    const saved = await this.repo.manager.transaction(async (manager) => {
      const userRepo = manager.getRepository(UserEntity);
      const userTerritoryRepo = manager.getRepository(UserTerritoryEntity);

      const user = userRepo.create({
        phone: input.phone.trim(),
        full_name: input.full_name.trim(),
        password_hash,
        role: input.role,
        division_id: geo.division_id,
        district_id: geo.district_id,
        zone_id: geo.zone_id,
        area_id: geo.area_id,
        territory_id: geo.territory_id,
        is_active: 1,
      });

      const savedUser = await userRepo.save(user);

      const assignment = userTerritoryRepo.create({
        user_id: Number(savedUser.id),
        territory_id: geo.territory_id,
        is_primary: 1,
        assigned_at: new Date(),
      });

      await userTerritoryRepo.save(assignment);

      return savedUser;
    });

    return this.sanitize(saved);
  }

  async updateUser(id: number, input: UserUpdateInput) {
    const user = await this.findById(id);
    if (!user) {
      throw new NotFoundException('User not found');
    }

    if (input.phone && input.phone.trim() !== user.phone) {
      const exists = await this.findByPhone(input.phone.trim());
      if (exists && exists.id !== user.id) {
        throw new BadRequestException('Phone already exists');
      }
      user.phone = input.phone.trim();
    }

    if (input.full_name?.trim()) {
      user.full_name = input.full_name.trim();
    }

    if (input.role) {
      user.role = input.role;
    }

    if (input.password?.trim()) {
      user.password_hash = await bcrypt.hash(input.password.trim(), 10);
    }

    const wantsGeoUpdate =
      input.division_id !== undefined ||
      input.district_id !== undefined ||
      input.zone_id !== undefined ||
      input.area_id !== undefined ||
      input.territory_id !== undefined;

    if (wantsGeoUpdate) {
      const geo = await this.validateGeoSelection({
        division_id: Number(input.division_id ?? user.division_id),
        district_id: Number(input.district_id ?? user.district_id),
        zone_id: Number(input.zone_id ?? user.zone_id),
        area_id: Number(input.area_id ?? user.area_id),
        territory_id: Number(input.territory_id ?? user.territory_id),
      });

      user.division_id = geo.division_id;
      user.district_id = geo.district_id;
      user.zone_id = geo.zone_id;
      user.area_id = geo.area_id;
      user.territory_id = geo.territory_id;

      await this.repo.manager.transaction(async (manager) => {
        const userRepo = manager.getRepository(UserEntity);
        const userTerritoryRepo = manager.getRepository(UserTerritoryEntity);

        const savedUser = await userRepo.save(user);

        await userTerritoryRepo.update(
          { user_id: Number(savedUser.id) },
          { is_primary: 0 },
        );

        const existing = await userTerritoryRepo.findOne({
          where: {
            user_id: Number(savedUser.id),
            territory_id: geo.territory_id,
          },
        });

        if (existing) {
          existing.is_primary = 1;
          if (!existing.assigned_at) {
            existing.assigned_at = new Date();
          }
          await userTerritoryRepo.save(existing);
        } else {
          const assignment = userTerritoryRepo.create({
            user_id: Number(savedUser.id),
            territory_id: geo.territory_id,
            is_primary: 1,
            assigned_at: new Date(),
          });
          await userTerritoryRepo.save(assignment);
        }
      });

      const fresh = await this.findById(id);
      return this.sanitize(fresh);
    }

    const saved = await this.repo.save(user);
    return this.sanitize(saved);
  }

  async setStatus(id: number, is_active: number) {
    const user = await this.findById(id);
    if (!user) {
      throw new NotFoundException('User not found');
    }

    user.is_active = is_active ? 1 : 0;
    const saved = await this.repo.save(user);
    return this.sanitize(saved);
  }
}