import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ApprovalsController } from './approvals.controller';
import { ApprovalsService } from './approvals.service';
import { ApprovalEntity } from './approval.entity';
import { InvoiceEntity } from '../invoices/invoice.entity';
import { CollectionEntity } from '../collections/collection.entity';
import { ExpenseEntity } from '../expenses/expense.entity';
import { NotificationEntity } from '../notifications/notification.entity';
import { AuditLogEntity } from '../sync/audit-log.entity';
import { InvoicesModule } from '../invoices/invoices.module';
import { CollectionsModule } from '../collections/collections.module';
import { ExpensesModule } from '../expenses/expenses.module';
// import { AccountingModule } from '../accounting/accounting.module';
import { GeoModule } from '../geo/geo.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      ApprovalEntity,
      InvoiceEntity,
      CollectionEntity,
      ExpenseEntity,
      NotificationEntity,
      AuditLogEntity,
    ]),
    InvoicesModule,
    CollectionsModule,
    ExpensesModule,
    // AccountingModule,
    GeoModule,
  ],
  controllers: [ApprovalsController],
  providers: [ApprovalsService],
})
export class ApprovalsModule {}