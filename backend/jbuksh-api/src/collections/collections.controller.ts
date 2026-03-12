import { Body, Controller, Get, Param, Post, Query, Req, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { TerritoryScoped } from '../auth/territory-scoped.decorator';
import { TerritoryScopeGuard } from '../auth/territory-scope.guard';
import { CollectionsService } from './collections.service';

@Controller('api/v1/collections')
@UseGuards(JwtAuthGuard, TerritoryScopeGuard)
@TerritoryScoped()
export class CollectionsController {
  constructor(private readonly collections: CollectionsService) {}

  @Post()
  create(
    @Req() req: any,
    @Body()
    body: {
      territory_id?: number;
      party_id: number;
      collection_date: string;
      method: 'CASH' | 'BANK' | 'MFS';
      amount: number;
      reference_no?: string | null;
    },
  ) {
    return this.collections.create(req.user, req.scope, body);
  }

  @Post(':id/submit')
  submit(@Req() req: any, @Param('id') id: string) {
    return this.collections.submit(Number(id), req.user, req.scope);
  }

  @Post(':id/allocate')
  allocate(
    @Req() req: any,
    @Param('id') id: string,
    @Body() body: { allocations: Array<{ invoice_id: number; applied_amount: number }> },
  ) {
    return this.collections.allocate(Number(id), body.allocations, req.user, req.scope);
  }

  @Get()
  list(
    @Req() req: any,
    @Query('status') status?: string,
    @Query('party_id') party_id?: string,
  ) {
    return this.collections.list(
      req.user,
      req.scope,
      status,
      party_id ? Number(party_id) : undefined,
    );
  }
}