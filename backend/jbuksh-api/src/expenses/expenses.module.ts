import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ExpensesController } from './expenses.controller';
import { ExpensesService } from './expenses.service';
import { ExpenseEntity } from './expense.entity';
import { ExpenseHeadEntity } from './expense-head.entity';
import { ApprovalEntity } from '../approvals/approval.entity';
import { AuditLogEntity } from '../sync/audit-log.entity';
import { GeoModule } from '../geo/geo.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      ExpenseEntity,
      ExpenseHeadEntity,
      ApprovalEntity,
      AuditLogEntity,
    ]),
    GeoModule,
  ],
  controllers: [ExpensesController],
  providers: [ExpensesService],
  exports: [ExpensesService],
})
export class ExpensesModule {}