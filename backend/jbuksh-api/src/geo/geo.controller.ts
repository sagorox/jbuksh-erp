import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  ParseIntPipe,
  Patch,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';
import { Role } from '../auth/roles.enum';
import { GeoService } from './geo.service';

@Controller('api/v1/geo')
@UseGuards(JwtAuthGuard, RolesGuard)
export class GeoController {
  constructor(private readonly geoService: GeoService) {}

  @Get('divisions')
  async divisions() {
    const items = await this.geoService.listDivisions();
    return { ok: true, divisions: items };
  }

  @Get('districts')
  async districts(@Query('division_id') divisionId?: string) {
    const items = await this.geoService.listDistricts(
      divisionId ? Number(divisionId) : undefined,
    );
    return { ok: true, districts: items };
  }

  @Get('zones')
  async zones() {
    const items = await this.geoService.listZones();
    return { ok: true, zones: items };
  }

  @Get('areas')
  async areas(@Query('zone_id') zoneId?: string) {
    const items = await this.geoService.listAreas(
      zoneId ? Number(zoneId) : undefined,
    );
    return { ok: true, areas: items };
  }

  @Get('territories')
  async territories(
    @Query('area_id') areaId?: string,
    @Query('district_id') districtId?: string,
  ) {
    const items = await this.geoService.listTerritories(
      areaId ? Number(areaId) : undefined,
      districtId ? Number(districtId) : undefined,
    );
    return { ok: true, territories: items };
  }

  @Post('territories')
  @Roles(Role.SUPER_ADMIN)
  createTerritory(
    @Body()
    body: {
      area_id?: number | null;
      district_id?: number | null;
      name: string;
      code: string;
      is_active?: number;
    },
  ) {
    return this.geoService.createTerritory(body);
  }

  @Get('users/:userId/territories')
  async userTerritories(@Param('userId', ParseIntPipe) userId: number) {
    const items = await this.geoService.getUserTerritories(userId);
    return { ok: true, territories: items };
  }

  @Post('users/:userId/territories')
  @Roles(Role.SUPER_ADMIN)
  assignTerritory(
    @Param('userId', ParseIntPipe) userId: number,
    @Body()
    body: {
      territory_id: number;
      is_primary?: number;
    },
  ) {
    return this.geoService.assignUserTerritory(userId, body);
  }

  @Delete('users/:userId/territories/:territoryId')
  @Roles(Role.SUPER_ADMIN)
  removeTerritory(
    @Param('userId', ParseIntPipe) userId: number,
    @Param('territoryId', ParseIntPipe) territoryId: number,
  ) {
    return this.geoService.removeUserTerritory(userId, territoryId);
  }

  @Patch('users/:userId/territories/:territoryId/primary')
  @Roles(Role.SUPER_ADMIN)
  makePrimary(
    @Param('userId', ParseIntPipe) userId: number,
    @Param('territoryId', ParseIntPipe) territoryId: number,
  ) {
    return this.geoService.makePrimaryUserTerritory(userId, territoryId);
  }
}