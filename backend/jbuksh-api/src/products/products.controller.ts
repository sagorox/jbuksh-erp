import {
  Body,
  Controller,
  Get,
  Param,
  ParseIntPipe,
  Post,
  Put,
  UseGuards,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';
import { Role } from '../auth/roles.enum';
import { ProductsService } from './products.service';

@Controller('api/v1/products')
@UseGuards(JwtAuthGuard, RolesGuard)
export class ProductsController {
  constructor(private readonly products: ProductsService) {}

  @Post()
  @Roles(Role.SUPER_ADMIN, Role.STOCK_KEEPER)
  create(
    @Body()
    body: {
      sku: string;
      name: string;
      category_id: number;
      unit: string;
      potency_tag?: string | null;
      purchase_price: number;
      sale_price: number;
      reorder_level?: number;
      in_stock?: number;
      is_active?: number;
    },
  ) {
    return this.products.create(body);
  }

  @Put(':id')
  @Roles(Role.SUPER_ADMIN, Role.STOCK_KEEPER)
  update(
    @Param('id', ParseIntPipe) id: number,
    @Body()
    body: {
      sku?: string;
      name?: string;
      category_id?: number;
      unit?: string;
      potency_tag?: string | null;
      purchase_price?: number;
      sale_price?: number;
      reorder_level?: number;
      in_stock?: number;
      is_active?: number;
    },
  ) {
    return this.products.update(id, body);
  }

  @Get()
  list() {
    return this.products.list();
  }

  @Get(':id')
  details(@Param('id', ParseIntPipe) id: number) {
    return this.products.details(id);
  }

  @Get(':id/batches')
  batchList(@Param('id', ParseIntPipe) id: number) {
    return this.products.batchList(id);
  }

  @Post(':id/batches')
  @Roles(Role.SUPER_ADMIN, Role.STOCK_KEEPER)
  createBatch(
    @Param('id', ParseIntPipe) id: number,
    @Body()
    body: {
      batch_no: string;
      mfg_date?: string | null;
      exp_date?: string | null;
      qty: number;
      mrp?: number;
      purchase_price?: number;
    },
  ) {
    return this.products.createBatch(id, body);
  }

  @Put('batches/:batchId')
  @Roles(Role.SUPER_ADMIN, Role.STOCK_KEEPER)
  updateBatch(
    @Param('batchId', ParseIntPipe) batchId: number,
    @Body()
    body: {
      batch_no?: string;
      mfg_date?: string | null;
      exp_date?: string | null;
      qty?: number;
      mrp?: number;
      purchase_price?: number;
    },
  ) {
    return this.products.updateBatch(batchId, body);
  }
}