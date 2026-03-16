import { Controller, Get, Query, Req, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { TerritoryScopeGuard } from '../auth/territory-scope.guard';
import { TerritoryScoped } from '../auth/territory-scoped.decorator';
import { ReportsService } from './reports.service';

@Controller('api/v1/reports')
@UseGuards(JwtAuthGuard, TerritoryScopeGuard)
@TerritoryScoped()
export class ReportsController {
  constructor(private readonly reports: ReportsService) {}

  @Get('sales-summary')
  salesSummary(
    @Req() req: any,
    @Query('from') from?: string,
    @Query('to') to?: string,
    @Query('territory_id') territory_id?: string,
    @Query('party_id') party_id?: string,
    @Query('user_id') user_id?: string,
  ) {
    return this.reports.salesSummary(
      req.user,
      req.scope,
      {
        from,
        to,
        territory_id: territory_id ? Number(territory_id) : undefined,
        party_id: party_id ? Number(party_id) : undefined,
        user_id: user_id ? Number(user_id) : undefined,
      },
    );
  }

  @Get('collections-summary')
  collectionsSummary(
    @Req() req: any,
    @Query('from') from?: string,
    @Query('to') to?: string,
    @Query('territory_id') territory_id?: string,
    @Query('party_id') party_id?: string,
    @Query('user_id') user_id?: string,
  ) {
    return this.reports.collectionsSummary(
      req.user,
      req.scope,
      {
        from,
        to,
        territory_id: territory_id ? Number(territory_id) : undefined,
        party_id: party_id ? Number(party_id) : undefined,
        user_id: user_id ? Number(user_id) : undefined,
      },
    );
  }

  @Get('stock-summary')
  stockSummary(
    @Req() req: any,
    @Query('from') from?: string,
    @Query('to') to?: string,
    @Query('territory_id') territory_id?: string,
    @Query('party_id') party_id?: string,
    @Query('user_id') user_id?: string,
  ) {
    return this.reports.stockSummary(
      req.user,
      req.scope,
      {
        from,
        to,
        territory_id: territory_id ? Number(territory_id) : undefined,
        party_id: party_id ? Number(party_id) : undefined,
        user_id: user_id ? Number(user_id) : undefined,
      },
    );
  }

  @Get('expense-summary')
  expenseSummary(
    @Req() req: any,
    @Query('from') from?: string,
    @Query('to') to?: string,
    @Query('territory_id') territory_id?: string,
    @Query('party_id') party_id?: string,
    @Query('user_id') user_id?: string,
  ) {
    return this.reports.expenseSummary(
      req.user,
      req.scope,
      {
        from,
        to,
        territory_id: territory_id ? Number(territory_id) : undefined,
        party_id: party_id ? Number(party_id) : undefined,
        user_id: user_id ? Number(user_id) : undefined,
      },
    );
  }
}