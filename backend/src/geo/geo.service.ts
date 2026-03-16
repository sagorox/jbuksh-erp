import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { In, Repository } from 'typeorm';

import { DivisionEntity } from '../divisions/division.entity';
import { DistrictEntity } from '../districts/district.entity';
import { ZoneEntity } from '../zones/zone.entity';
import { AreaEntity } from '../areas/area.entity';

import { TerritoryEntity } from './territory.entity';
import { UserTerritoryEntity } from './user-territory.entity';
import { UserEntity } from '../users/user.entity';
import { Role } from '../auth/roles.enum';

@Injectable()
export class GeoService {
  constructor(
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
    @InjectRepository(UserEntity)
    private readonly userRepo: Repository<UserEntity>,
  ) {}

  async listDivisions() {
    return this.divisionRepo.find({
      order: { id: 'ASC' as any },
    });
  }

  async listDistricts(divisionId?: number) {
    if (divisionId) {
      return this.districtRepo.find({
        where: { division_id: Number(divisionId) },
        order: { id: 'ASC' as any },
      });
    }

    return this.districtRepo.find({
      order: { id: 'ASC' as any },
    });
  }

  async listZones() {
    return this.zoneRepo.find({
      order: { id: 'ASC' as any },
    });
  }

  async listAreas(zoneId?: number) {
    if (zoneId) {
      return this.areaRepo.find({
        where: { zone_id: Number(zoneId) },
        order: { id: 'ASC' as any },
      });
    }

    return this.areaRepo.find({
      order: { id: 'ASC' as any },
    });
  }

  async listTerritories(areaId?: number, districtId?: number) {
    const where: Record<string, any> = {};

    if (areaId) {
      where.area_id = Number(areaId);
    }

    if (districtId) {
      where.district_id = Number(districtId);
    }

    return this.territoryRepo.find({
      where,
      order: { id: 'ASC' as any },
    });
  }

  async createTerritory(input: {
    area_id?: number | null;
    district_id?: number | null;
    name: string;
    code: string;
    is_active?: number;
  }) {
    if (!input.name?.trim()) {
      throw new BadRequestException('name is required');
    }

    if (!input.code?.trim()) {
      throw new BadRequestException('code is required');
    }

    const areaId = Number(input.area_id);
    const districtId = Number(input.district_id);

    if (!areaId || !districtId) {
      throw new BadRequestException('area_id and district_id are required');
    }

    const [area, district, existingCode] = await Promise.all([
      this.areaRepo.findOne({ where: { id: areaId } }),
      this.districtRepo.findOne({ where: { id: districtId } }),
      this.territoryRepo.findOne({
        where: { code: input.code.trim() },
      }),
    ]);

    if (!area) {
      throw new BadRequestException('Area not found');
    }

    if (!district) {
      throw new BadRequestException('District not found');
    }

    if (existingCode) {
      throw new BadRequestException('code already exists');
    }

    const existingSameName = await this.territoryRepo.findOne({
      where: {
        name: input.name.trim(),
        area_id: areaId,
        district_id: districtId,
      },
    });

    if (existingSameName) {
      throw new BadRequestException(
        'Same territory name already exists under selected area and district',
      );
    }

    const territory = this.territoryRepo.create({
      area_id: areaId,
      district_id: districtId,
      name: input.name.trim(),
      code: input.code.trim(),
      is_active: Number(input.is_active ?? 1),
    });

    const saved = await this.territoryRepo.save(territory);
    return { ok: true, territory: saved };
  }

  async getUserTerritoryIds(userId: number): Promise<number[]> {
    const rows = await this.userTerritoryRepo.find({
      where: { user_id: Number(userId) },
      order: { is_primary: 'DESC' as any, id: 'ASC' as any },
    });

    return rows.map((x) => Number(x.territory_id));
  }

  async getUserTerritories(userId: number) {
    const rows = await this.userTerritoryRepo.find({
      where: { user_id: Number(userId) },
      order: { is_primary: 'DESC' as any, id: 'ASC' as any },
    });

    if (!rows.length) return [];

    const territoryIds = rows.map((x) => Number(x.territory_id));

    const territories = await this.territoryRepo.find({
      where: { id: In(territoryIds) },
      order: { id: 'ASC' as any },
    });

    const territoryMap = new Map<number, TerritoryEntity>();
    for (const t of territories) {
      territoryMap.set(Number(t.id), t);
    }

    return rows.map((row) => ({
      ...territoryMap.get(Number(row.territory_id)),
      assignment: {
        user_id: Number(row.user_id),
        territory_id: Number(row.territory_id),
        is_primary: Number(row.is_primary ?? 0),
        assigned_at: row.assigned_at ?? null,
      },
    }));
  }

  async assignUserTerritory(
    userId: number,
    input: {
      territory_id: number;
      is_primary?: number;
    },
  ) {
    const user = await this.mustFindAssignableUser(userId);

    const territory = await this.territoryRepo.findOne({
      where: { id: Number(input.territory_id) },
    });

    if (!territory) {
      throw new NotFoundException('Territory not found');
    }

    const existing = await this.userTerritoryRepo.findOne({
      where: {
        user_id: Number(user.id),
        territory_id: Number(input.territory_id),
      },
    });

    if (existing) {
      if (Number(input.is_primary ?? 0) === 1) {
        await this.userTerritoryRepo.update(
          { user_id: Number(user.id) },
          { is_primary: 0 },
        );

        existing.is_primary = 1;
        if (!existing.assigned_at) {
          existing.assigned_at = new Date();
        }
        await this.userTerritoryRepo.save(existing);
      }

      return {
        ok: true,
        message: 'Territory already assigned',
        assignment: existing,
      };
    }

    const shouldBePrimary =
        Number(input.is_primary ?? 0) === 1 ||
        (await this.userTerritoryRepo.count({
              where: { user_id: Number(user.id) },
            })) ==
            0;

    if (shouldBePrimary) {
      await this.userTerritoryRepo.update(
        { user_id: Number(user.id) },
        { is_primary: 0 },
      );
    }

    const assignment = this.userTerritoryRepo.create({
      user_id: Number(user.id),
      territory_id: Number(input.territory_id),
      is_primary: shouldBePrimary ? 1 : 0,
      assigned_at: new Date(),
    });

    const saved = await this.userTerritoryRepo.save(assignment);

    return { ok: true, assignment: saved };
  }

  async removeUserTerritory(userId: number, territoryId: number) {
    await this.mustFindAssignableUser(userId);

    const assignment = await this.userTerritoryRepo.findOne({
      where: {
        user_id: Number(userId),
        territory_id: Number(territoryId),
      },
    });

    if (!assignment) {
      throw new NotFoundException('User territory assignment not found');
    }

    const wasPrimary = Number(assignment.is_primary ?? 0) === 1;

    await this.userTerritoryRepo.delete({
      user_id: Number(userId),
      territory_id: Number(territoryId),
    });

    if (wasPrimary) {
      const next = await this.userTerritoryRepo.findOne({
        where: { user_id: Number(userId) },
        order: { id: 'ASC' as any },
      });

      if (next) {
        next.is_primary = 1;
        await this.userTerritoryRepo.save(next);
      }
    }

    return { ok: true };
  }

  async makePrimaryUserTerritory(userId: number, territoryId: number) {
    await this.mustFindAssignableUser(userId);

    const assignment = await this.userTerritoryRepo.findOne({
      where: {
        user_id: Number(userId),
        territory_id: Number(territoryId),
      },
    });

    if (!assignment) {
      throw new NotFoundException('User territory assignment not found');
    }

    await this.userTerritoryRepo.update(
      { user_id: Number(userId) },
      { is_primary: 0 },
    );

    assignment.is_primary = 1;
    if (!assignment.assigned_at) {
      assignment.assigned_at = new Date();
    }

    const saved = await this.userTerritoryRepo.save(assignment);
    return { ok: true, assignment: saved };
  }

  private async mustFindAssignableUser(userId: number) {
    const user = await this.userRepo.findOne({
      where: { id: Number(userId) },
    });

    if (!user) {
      throw new NotFoundException('User not found');
    }

    if (![Role.MPO, Role.RSM].includes(user.role)) {
      throw new BadRequestException(
        'Territory assignment is allowed only for MPO or RSM',
      );
    }

    return user;
  }
}