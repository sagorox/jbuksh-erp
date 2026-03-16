import { Body, Controller, Get, Param, Post, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';
import { Role } from '../auth/roles.enum';
import { StockService } from './stock.service';

@Controller('api/v1/stock')
@UseGuards(JwtAuthGuard, RolesGuard)
export class StockController {
  constructor(private readonly stock: StockService) {}

  @Get('summary')
  summary() {
    return this.stock.summary();
  }

  @Get('item/:productId')
  item(@Param('productId') productId: string) {
    return this.stock.itemDetails(Number(productId));
  }

  @Post('adjust')
  @Roles(Role.SUPER_ADMIN, Role.STOCK_KEEPER)
  adjust(@Body() body: { product_id: number; qty: number }) {
    return this.stock.adjust(body);
  }
}