import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { UsersController } from './users.controller';
import { UsersService } from './users.service';
import { UserEntity } from './user.entity';
import { DivisionEntity } from '../divisions/division.entity';
import { DistrictEntity } from '../districts/district.entity';
import { ZoneEntity } from '../zones/zone.entity';
import { AreaEntity } from '../areas/area.entity';
import { TerritoryEntity } from '../geo/territory.entity';
import { UserTerritoryEntity } from '../geo/user-territory.entity';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      UserEntity,
      DivisionEntity,
      DistrictEntity,
      ZoneEntity,
      AreaEntity,
      TerritoryEntity,
      UserTerritoryEntity,
    ]),
  ],
  controllers: [UsersController],
  providers: [UsersService],
  exports: [UsersService],
})
export class UsersModule {}