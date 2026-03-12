import {
  Body,
  Controller,
  Get,
  Param,
  ParseIntPipe,
  Post,
  Put,
  Req,
  UseGuards,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { TerritoryScoped } from '../auth/territory-scoped.decorator';
import { TerritoryScopeGuard } from '../auth/territory-scope.guard';
import { PartiesService } from './parties.service';

@Controller('api/v1/parties')
@UseGuards(JwtAuthGuard, TerritoryScopeGuard)
@TerritoryScoped()
export class PartiesController {
  constructor(private readonly parties: PartiesService) {}

  @Post()
  create(
    @Req() req: any,
    @Body()
    body: {
      territory_id?: number;
      party_code: string;
      name: string;
      assigned_mpo_user_id?: number | null;
    },
  ) {
    return this.parties.create(req.user, req.scope, body);
  }

  @Get()
  list(@Req() req: any) {
    return this.parties.list(req.user, req.scope);
  }

  @Get(':id/summary')
  summary(@Req() req: any, @Param('id', ParseIntPipe) id: number) {
    return this.parties.summary(id, req.user, req.scope);
  }

  @Get(':id')
  details(@Req() req: any, @Param('id', ParseIntPipe) id: number) {
    return this.parties.details(id, req.user, req.scope);
  }

  @Put(':id')
  update(
    @Req() req: any,
    @Param('id', ParseIntPipe) id: number,
    @Body()
    body: {
      territory_id?: number;
      party_code?: string;
      name?: string;
      credit_limit?: number;
      is_active?: number;
      assigned_mpo_user_id?: number | null;
    },
  ) {
    return this.parties.update(id, req.user, req.scope, body);
  }
}