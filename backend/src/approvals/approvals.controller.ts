import {
  Body,
  Controller,
  Get,
  Param,
  ParseIntPipe,
  Post,
  Query,
  Req,
  UseGuards,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { TerritoryScopeGuard } from '../auth/territory-scope.guard';
import { ApprovalsService } from './approvals.service';

@UseGuards(JwtAuthGuard, TerritoryScopeGuard)
@Controller('api/v1/approvals')
export class ApprovalsController {
  constructor(private readonly approvals: ApprovalsService) {}

  @Get()
  list(
    @Req() req: any,
    @Query('status') status?: string,
    @Query('entity_type') entityType?: string,
  ) {
    return this.approvals.list(req.user, req.scope, status, entityType);
  }

  @Post(':id/approve')
  approve(
    @Req() req: any,
    @Param('id', ParseIntPipe) id: number,
    @Body() body: { reason?: string },
  ) {
    return this.approvals.approve(id, req.user, req.scope, body?.reason || null);
  }

  @Post(':id/decline')
  decline(
    @Req() req: any,
    @Param('id', ParseIntPipe) id: number,
    @Body() body: { reason: string },
  ) {
    return this.approvals.decline(id, req.user, req.scope, body?.reason || null);
  }
}