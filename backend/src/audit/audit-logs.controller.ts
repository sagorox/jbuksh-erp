import {
  Controller,
  Get,
  Param,
  ParseIntPipe,
  Query,
  UseGuards,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';
import { Role } from '../auth/roles.enum';
import { AuditLogsService } from './audit-logs.service';

@Controller('api/v1/audit-logs')
@UseGuards(JwtAuthGuard, RolesGuard)
export class AuditLogsController {
  constructor(private readonly auditLogs: AuditLogsService) {}

  @Get()
  @Roles(Role.SUPER_ADMIN)
  list(
    @Query('entity_type') entity_type?: string,
    @Query('entity_id') entity_id?: string,
    @Query('actor_user_id') actor_user_id?: string,
    @Query('from') from?: string,
    @Query('to') to?: string,
  ) {
    return this.auditLogs.list({
      entity_type,
      entity_id: entity_id ? Number(entity_id) : undefined,
      actor_user_id: actor_user_id ? Number(actor_user_id) : undefined,
      from,
      to,
    });
  }

  @Get(':id')
  @Roles(Role.SUPER_ADMIN)
  details(@Param('id', ParseIntPipe) id: number) {
    return this.auditLogs.details(id);
  }
}