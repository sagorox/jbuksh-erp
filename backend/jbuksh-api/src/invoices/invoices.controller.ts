import { Body, Controller, Get, Param, Post, Query, Req, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { TerritoryScoped } from '../auth/territory-scoped.decorator';
import { TerritoryScopeGuard } from '../auth/territory-scope.guard';
import { InvoicesService } from './invoices.service';

@Controller('api/v1/invoices')
@UseGuards(JwtAuthGuard, TerritoryScopeGuard)
@TerritoryScoped()
export class InvoicesController {
  constructor(private readonly invoices: InvoicesService) {}

  @Post()
  createDraft(
    @Req() req: any,
    @Body()
    body: {
      territory_id?: number;
      party_id: number;
      invoice_date: string;
      invoice_time: string;
      discount_percent?: number;
      discount_amount?: number;
      remarks?: string | null;
    },
  ) {
    return this.invoices.createDraft(req.user, req.scope, body);
  }

  @Post(':id/items')
  addItems(
    @Req() req: any,
    @Param('id') id: string,
    @Body() body: { items: Array<{ product_id: number; qty: number; free_qty?: number; unit_price: number }> },
  ) {
    return this.invoices.addItems(Number(id), body.items, req.user, req.scope);
  }

  @Post(':id/submit')
  submit(@Req() req: any, @Param('id') id: string) {
    return this.invoices.submit(Number(id), req.user, req.scope);
  }

  @Post(':id/cancel')
  cancel(@Req() req: any, @Param('id') id: string) {
    return this.invoices.cancel(Number(id), req.user, req.scope);
  }

  @Post(':id/generate-pdf')
  generatePdf(@Req() req: any, @Param('id') id: string) {
    return this.invoices.generatePdf(Number(id), req.user, req.scope);
  }

  @Get()
  list(
    @Req() req: any,
    @Query('status') status?: string,
    @Query('party_id') party_id?: string,
  ) {
    return this.invoices.list(
      req.user,
      req.scope,
      status,
      party_id ? Number(party_id) : undefined,
    );
  }
}