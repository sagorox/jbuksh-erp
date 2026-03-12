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
  divisions() {
    return this.geoService.listDivisions();
  }

  @Get('districts')
  districts(@Query('division_id') divisionId?: string) {
    return this.geoService.listDistricts(
      divisionId ? Number(divisionId) : undefined,
    );
  }

  @Get('zones')
  zones() {
    return this.geoService.listZones();
  }

  @Get('areas')
  areas(@Query('zone_id') zoneId?: string) {
    return this.geoService.listAreas(zoneId ? Number(zoneId) : undefined);
  }

  @Get('territories')
  territories(
    @Query('area_id') areaId?: string,
    @Query('district_id') districtId?: string,
  ) {
    return this.geoService.listTerritories(
      areaId ? Number(areaId) : undefined,
      districtId ? Number(districtId) : undefined,
    );
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
  userTerritories(@Param('userId', ParseIntPipe) userId: number) {
    return this.geoService.getUserTerritories(userId);
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