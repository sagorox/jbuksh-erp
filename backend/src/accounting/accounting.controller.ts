import {
  Body,
  Controller,
  Get,
  Param,
  ParseIntPipe,
  Patch,
  Post,
  Query,
  Req,
  UseGuards,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';
import { Role } from '../auth/roles.enum';
import { TerritoryScoped } from '../auth/territory-scoped.decorator';
import { TerritoryScopeGuard } from '../auth/territory-scope.guard';
import { AccountingService } from './accounting.service';
import { AccountingVoucherStatus } from './accounting-voucher.entity';

@Controller('api/v1/accounting')
@UseGuards(JwtAuthGuard, RolesGuard, TerritoryScopeGuard)
@TerritoryScoped()
export class AccountingController {
  constructor(private readonly accounting: AccountingService) {}

  @Get('summary')
  @Roles(Role.SUPER_ADMIN, Role.ACCOUNTING, Role.RSM)
  summary(
    @Req() req: any,
    @Query('from') from?: string,
    @Query('to') to?: string,
    @Query('territory_id') territory_id?: string,
    @Query('party_id') party_id?: string,
    @Query('user_id') user_id?: string,
    @Query('status') status?: string,
  ) {
    return this.accounting.summary(req.user, req.scope, {
      from,
      to,
      territory_id: territory_id ? Number(territory_id) : undefined,
      party_id: party_id ? Number(party_id) : undefined,
      user_id: user_id ? Number(user_id) : undefined,
      status,
    });
  }

  @Get('ledger')
  @Roles(Role.SUPER_ADMIN, Role.ACCOUNTING, Role.RSM)
  ledger(
    @Req() req: any,
    @Query('from') from?: string,
    @Query('to') to?: string,
    @Query('territory_id') territory_id?: string,
    @Query('party_id') party_id?: string,
    @Query('user_id') user_id?: string,
    @Query('status') status?: string,
  ) {
    return this.accounting.ledger(req.user, req.scope, {
      from,
      to,
      territory_id: territory_id ? Number(territory_id) : undefined,
      party_id: party_id ? Number(party_id) : undefined,
      user_id: user_id ? Number(user_id) : undefined,
      status,
    });
  }

  @Get('vouchers')
  @Roles(Role.SUPER_ADMIN, Role.ACCOUNTING, Role.RSM)
  vouchers(
    @Req() req: any,
    @Query('from') from?: string,
    @Query('to') to?: string,
    @Query('territory_id') territory_id?: string,
    @Query('party_id') party_id?: string,
    @Query('user_id') user_id?: string,
    @Query('status') status?: string,
  ) {
    return this.accounting.listVouchers(req.user, req.scope, {
      from,
      to,
      territory_id: territory_id ? Number(territory_id) : undefined,
      party_id: party_id ? Number(party_id) : undefined,
      user_id: user_id ? Number(user_id) : undefined,
      status,
    });
  }

  @Get('vouchers/:id')
  @Roles(Role.SUPER_ADMIN, Role.ACCOUNTING, Role.RSM)
  voucherDetails(
    @Req() req: any,
    @Param('id', ParseIntPipe) id: number,
  ) {
    return this.accounting.voucherDetails(id, req.user, req.scope);
  }

  @Post('vouchers')
  @Roles(Role.SUPER_ADMIN, Role.ACCOUNTING)
  createVoucher(
    @Req() req: any,
    @Body()
    body: {
      voucher_date: string;
      voucher_type: 'DEBIT' | 'CREDIT';
      amount: number;
      territory_id?: number | null;
      party_id?: number | null;
      user_id?: number | null;
      reference_type?: string | null;
      reference_id?: number | null;
      description?: string | null;
      status?: AccountingVoucherStatus;
    },
  ) {
    return this.accounting.createVoucher(req.user, req.scope, body);
  }

  @Patch('vouchers/:id/status')
  @Roles(Role.SUPER_ADMIN, Role.ACCOUNTING)
  updateVoucherStatus(
    @Req() req: any,
    @Param('id', ParseIntPipe) id: number,
    @Body() body: { status: AccountingVoucherStatus },
  ) {
    return this.accounting.updateVoucherStatus(id, req.user, req.scope, body);
  }
}