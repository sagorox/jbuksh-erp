import { Body, Controller, Get, Post, Req, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';
import { Role } from '../auth/roles.enum';
import { SchedulesService } from './schedules.service';

@Controller('api/v1/schedules')
@UseGuards(JwtAuthGuard, RolesGuard)
export class SchedulesController {
  constructor(private readonly schedules: SchedulesService) {}

  @Post()
  @Roles(Role.SUPER_ADMIN, Role.RSM)
  async create(@Req() req: any, @Body() body: { name: string; start_date: string; end_date: string }) {
    const schedule = await this.schedules.createSchedule({ ...body, created_by: req.user.sub });
    return { ok: true, schedule };
  }

  @Post('assign')
  @Roles(Role.SUPER_ADMIN, Role.RSM)
  async assign(@Body() body: { work_schedule_id: number; user_id: number; territory_id?: number | null }) {
    const assignment = await this.schedules.assignSchedule(body);
    return { ok: true, assignment };
  }

  @Get()
  @Roles(Role.SUPER_ADMIN, Role.RSM)
  async listAll() {
    const schedules = await this.schedules.listSchedules();
    return { ok: true, schedules };
  }

  @Get('my')
  @Roles(Role.SUPER_ADMIN, Role.RSM, Role.MPO)
  async my(@Req() req: any) {
    const schedules = await this.schedules.listMySchedules(req.user.sub);
    return { ok: true, schedules };
  }
}
