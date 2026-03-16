import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import { AuthModule } from './auth/auth.module';
import { UsersModule } from './users/users.module';
import { GeoModule } from './geo/geo.module';
import { PartiesModule } from './parties/parties.module';
import { ProductsModule } from './products/products.module';
import { StockModule } from './stock/stock.module';
import { InvoicesModule } from './invoices/invoices.module';
import { ApprovalsModule } from './approvals/approvals.module';
import { CollectionsModule } from './collections/collections.module';
import { AttendanceModule } from './attendance/attendance.module';
import { SchedulesModule } from './schedules/schedules.module';
import { TargetsModule } from './targets/targets.module';
import { SyncModule } from './sync/sync.module';
import { DeliveriesModule } from './deliveries/deliveries.module';
import { ExpensesModule } from './expenses/expenses.module';
import { ReportsModule } from './reports/reports.module';
import { AuditModule } from './audit/audit.module';
import { NotificationsModule } from './notifications/notifications.module';
import { AccountingModule } from './accounting/accounting.module';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),

    TypeOrmModule.forRootAsync({
      inject: [ConfigService],
      useFactory: (cfg: ConfigService) => ({
        type: 'mysql',
        host: cfg.get<string>('DB_HOST'),
        port: Number(cfg.get<string>('DB_PORT') || 3306),
        username: cfg.get<string>('DB_USER'),
        password: cfg.get<string>('DB_PASS') || '',
        database: cfg.get<string>('DB_NAME'),
        autoLoadEntities: true,
        synchronize: String(cfg.get<string>('DB_SYNC') || 'false') === 'true',
      }),
    }),

    AuthModule,
    UsersModule,
    GeoModule,
    PartiesModule,
    ProductsModule,
    StockModule,
    InvoicesModule,
    ApprovalsModule,
    SchedulesModule,
    CollectionsModule,
    AttendanceModule,
    TargetsModule,
    SyncModule,
    DeliveriesModule,
    ExpensesModule,
    ReportsModule,
    AuditModule,
    NotificationsModule,
    AccountingModule,
  ],
  controllers: [AppController],
  providers: [AppService],
})
export class AppModule {}