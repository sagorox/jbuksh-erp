import { Body, Controller, Get, Post, Query, Req, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { TerritoryScoped } from '../auth/territory-scoped.decorator';
import { TerritoryScopeGuard } from '../auth/territory-scope.guard';
import { SyncService } from './sync.service';
import { SyncPushDto } from './sync.dto';

@Controller('api/v1/sync')
@UseGuards(JwtAuthGuard, TerritoryScopeGuard)
@TerritoryScoped()
export class SyncController {
  constructor(private readonly sync: SyncService) {}

  @Get('bootstrap')
  bootstrap(@Req() req: any) {
    return this.sync.bootstrap(req.user, req.scope);
  }

  @Get('pull')
  pull(@Req() req: any, @Query('since') since?: string) {
    return this.sync.pull(req.user, req.scope, since);
  }

  @Post('push')
  push(@Req() req: any, @Body() dto: SyncPushDto) {
    return this.sync.push(req.user, req.scope, dto);
  }
}
