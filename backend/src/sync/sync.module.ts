import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { SyncController } from './sync.controller';
import { SyncService } from './sync.service';
import { SyncChangeLogEntity } from './sync-change-log.entity';
import { AuditLogEntity } from './audit-log.entity';
import { PartyEntity } from '../parties/party.entity';
import { InvoiceEntity } from '../invoices/invoice.entity';
import { CollectionEntity } from '../collections/collection.entity';
import { ExpenseEntity } from '../expenses/expense.entity';
import { AttendanceEntity } from '../attendance/attendance.entity';
import { ProductEntity } from '../products/product.entity';
import { CategoryEntity } from '../products/category.entity';
import { TerritoryEntity } from '../geo/territory.entity';
import { DeliveryEntity } from '../deliveries/delivery.entity';
import { GeoModule } from '../geo/geo.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      SyncChangeLogEntity,
      AuditLogEntity,
      PartyEntity,
      InvoiceEntity,
      CollectionEntity,
      ExpenseEntity,
      AttendanceEntity,
      ProductEntity,
      CategoryEntity,
      TerritoryEntity,
      DeliveryEntity,
    ]),
    GeoModule,
  ],
  controllers: [SyncController],
  providers: [SyncService],
})
export class SyncModule {}