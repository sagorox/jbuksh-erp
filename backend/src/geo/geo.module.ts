import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';

import { GeoController } from './geo.controller';
import { GeoService } from './geo.service';

import { DivisionEntity } from '../divisions/division.entity';
import { DistrictEntity } from '../districts/district.entity';
import { ZoneEntity } from '../zones/zone.entity';
import { AreaEntity } from '../areas/area.entity';

import { TerritoryEntity } from './territory.entity';
import { UserTerritoryEntity } from './user-territory.entity';
import { UserEntity } from '../users/user.entity';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      DivisionEntity,
      DistrictEntity,
      ZoneEntity,
      AreaEntity,
      TerritoryEntity,
      UserTerritoryEntity,
      UserEntity,
    ]),
  ],
  controllers: [GeoController],
  providers: [GeoService],
  exports: [GeoService],
})
export class GeoModule {}