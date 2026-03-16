import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { PartyEntity } from './party.entity';
import { PartiesController } from './parties.controller';
import { PartiesService } from './parties.service';
import { GeoModule } from '../geo/geo.module';
import { UserEntity } from '../users/user.entity';
import { InvoiceEntity } from '../invoices/invoice.entity';
import { CollectionEntity } from '../collections/collection.entity';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      PartyEntity,
      UserEntity,
      InvoiceEntity,
      CollectionEntity,
    ]),
    GeoModule,
  ],
  controllers: [PartiesController],
  providers: [PartiesService],
})
export class PartiesModule {}