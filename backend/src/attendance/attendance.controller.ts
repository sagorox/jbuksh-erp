import { Body, Controller, Get, Post, Query, Req, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { TerritoryScoped } from '../auth/territory-scoped.decorator';
import { TerritoryScopeGuard } from '../auth/territory-scope.guard';
import { AttendanceService } from './attendance.service';

@Controller('api/v1/attendance')
@UseGuards(JwtAuthGuard, TerritoryScopeGuard)
@TerritoryScoped()
export class AttendanceController {
  constructor(private readonly attendance: AttendanceService) {}

  @Post('check-in')
  checkIn(
    @Req() req: any,
    @Body()
    body: { territory_id?: number; note?: string; geo_lat?: number; geo_lng?: number },
  ) {
    return this.attendance.checkIn({
      user_id: req.user.sub,
      territory_id: body.territory_id ?? null,
      note: body.note ?? null,
      geo_lat: body.geo_lat ?? null,
      geo_lng: body.geo_lng ?? null,
    });
  }

  @Post('check-out')
  checkOut(@Req() req: any) {
    return this.attendance.checkOut(req.user.sub);
  }

  @Get()
  list(@Query('user_id') user_id?: string) {
    return this.attendance.list(user_id ? Number(user_id) : undefined);
  }
}