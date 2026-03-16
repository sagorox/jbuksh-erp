import { Body, Controller, Get, Post, Query, Req, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';
import { Role } from '../auth/roles.enum';
import { TargetsService } from './targets.service';

@Controller('api/v1/targets')
@UseGuards(JwtAuthGuard, RolesGuard)
export class TargetsController {
  constructor(private readonly targets: TargetsService) {}

  // Admin/RSM sets target
  @Post('monthly')
  @Roles(Role.SUPER_ADMIN, Role.RSM)
  upsert(@Req() req: any, @Body() body: {
    user_id: number;
    territory_id?: number | null;
    year: number;
    month: number;
    sales_target: number;
    collection_target: number;
  }) {
    return this.targets.upsertTarget({ ...body, set_by: req.user.sub });
  }

  // MPO/RSM view targets for a user
  @Get('monthly')
  @Roles(Role.SUPER_ADMIN, Role.RSM, Role.MPO)
  get(@Query('user_id') user_id: string, @Query('year') year: string, @Query('month') month: string) {
    return this.targets.getTarget(Number(user_id), Number(year), Number(month));
  }

  // MPO performance dashboard
  @Get('dashboard')
  @Roles(Role.SUPER_ADMIN, Role.RSM, Role.MPO)
  dashboard(@Req() req: any, @Query('year') year: string, @Query('month') month: string) {
    return this.targets.dashboard(req.user.sub, Number(year), Number(month));
  }
}