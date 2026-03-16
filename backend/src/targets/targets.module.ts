import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { TargetsController } from './targets.controller';
import { TargetsService } from './targets.service';
import { MonthlyTargetEntity } from './monthly-target.entity';
import { InvoiceEntity } from '../invoices/invoice.entity';
import { CollectionEntity } from '../collections/collection.entity';

@Module({
  imports: [TypeOrmModule.forFeature([MonthlyTargetEntity, InvoiceEntity, CollectionEntity])],
  controllers: [TargetsController],
  providers: [TargetsService],
})
export class TargetsModule {}