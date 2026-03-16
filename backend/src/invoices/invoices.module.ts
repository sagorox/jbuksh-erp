import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { InvoicesController } from './invoices.controller';
import { InvoicesService } from './invoices.service';
import { InvoiceEntity } from './invoice.entity';
import { InvoiceItemEntity } from './invoice-item.entity';
import { ApprovalEntity } from '../approvals/approval.entity';
import { AuditLogEntity } from '../sync/audit-log.entity';
import { GeoModule } from '../geo/geo.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      InvoiceEntity,
      InvoiceItemEntity,
      ApprovalEntity,
      AuditLogEntity,
    ]),
    GeoModule,
  ],
  controllers: [InvoicesController],
  providers: [InvoicesService],
  exports: [InvoicesService],
})
export class InvoicesModule {}