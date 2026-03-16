import { Body, Controller, Get, Param, Post, Query, Req, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';
import { Role } from '../auth/roles.enum';
import { DeliveriesService } from './deliveries.service';

@Controller('api/v1/deliveries')
@UseGuards(JwtAuthGuard, RolesGuard)
export class DeliveriesController {
  constructor(private readonly deliveries: DeliveriesService) {}

  // create PACKED delivery from invoice
  @Post()
  @Roles(Role.SUPER_ADMIN, Role.STOCK_KEEPER)
  create(@Body() body: { invoice_id: number; warehouse_id?: number | null }) {
    return this.deliveries.createFromInvoice(body);
  }

  @Post(':id/dispatch')
  @Roles(Role.SUPER_ADMIN, Role.STOCK_KEEPER)
  dispatch(@Param('id') id: string) {
    return this.deliveries.dispatch(Number(id));
  }

  @Post(':id/confirm-delivered')
  @Roles(Role.SUPER_ADMIN, Role.STOCK_KEEPER)
  confirm(@Req() req: any, @Param('id') id: string) {
    return this.deliveries.confirmDelivered(Number(id), req.user.sub);
  }

  @Get(':id')
  @Roles(Role.SUPER_ADMIN, Role.STOCK_KEEPER)
  getOne(@Param('id') id: string) {
    return this.deliveries.getOne(Number(id));
  }

  @Get()
  @Roles(Role.SUPER_ADMIN, Role.STOCK_KEEPER)
  list(@Query('status') status?: string) {
    return this.deliveries.list(status);
  }
}