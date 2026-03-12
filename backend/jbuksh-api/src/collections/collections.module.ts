import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { CollectionsController } from './collections.controller';
import { CollectionsService } from './collections.service';
import { CollectionEntity } from './collection.entity';
import { CollectionAllocationEntity } from './collection-allocation.entity';
import { InvoiceEntity } from '../invoices/invoice.entity';
import { ApprovalEntity } from '../approvals/approval.entity';
import { AuditLogEntity } from '../sync/audit-log.entity';
import { GeoModule } from '../geo/geo.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      CollectionEntity,
      CollectionAllocationEntity,
      InvoiceEntity,
      ApprovalEntity,
      AuditLogEntity,
    ]),
    GeoModule,
  ],
  controllers: [CollectionsController],
  providers: [CollectionsService],
  exports: [CollectionsService],
})
export class CollectionsModule {}