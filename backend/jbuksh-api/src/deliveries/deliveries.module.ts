import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { DeliveryEntity } from './delivery.entity';
import { DeliveryItemEntity } from './delivery-item.entity';
import { DeliveriesController } from './deliveries.controller';
import { DeliveriesService } from './deliveries.service';
import { InvoiceEntity } from '../invoices/invoice.entity';
import { InvoiceItemEntity } from '../invoices/invoice-item.entity';
import { ProductEntity } from '../products/product.entity';

@Module({
  imports: [TypeOrmModule.forFeature([DeliveryEntity, DeliveryItemEntity, InvoiceEntity, InvoiceItemEntity, ProductEntity])],
  controllers: [DeliveriesController],
  providers: [DeliveriesService],
})
export class DeliveriesModule {}