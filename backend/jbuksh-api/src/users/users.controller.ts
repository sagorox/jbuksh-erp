import { Body, Controller, Get, Param, ParseIntPipe, Patch, Post, Put, Query, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';
import { Role } from '../auth/roles.enum';
import { UsersService } from './users.service';

@Controller('api/v1/users')
@UseGuards(JwtAuthGuard, RolesGuard)
export class UsersController {
  constructor(private readonly users: UsersService) {}

  @Get()
  @Roles(Role.SUPER_ADMIN, Role.RSM)
  async list(@Query('q') q?: string, @Query('role') role?: Role) {
    const users = await this.users.listUsers({ q, role });
    return { ok: true, users };
  }

  @Post()
  @Roles(Role.SUPER_ADMIN)
  async create(@Body() body: { phone: string; full_name: string; password: string; role: Role }) {
    const user = await this.users.createUser({
      phone: body.phone,
      full_name: body.full_name,
      password: body.password,
      role: body.role,
    });
    return { ok: true, user };
  }

  @Put(':id')
  @Roles(Role.SUPER_ADMIN)
  async update(
    @Param('id', ParseIntPipe) id: number,
    @Body() body: { phone?: string; full_name?: string; password?: string; role?: Role },
  ) {
    const user = await this.users.updateUser(id, body);
    return { ok: true, user };
  }

  @Patch(':id/status')
  @Roles(Role.SUPER_ADMIN)
  async status(@Param('id', ParseIntPipe) id: number, @Body() body: { is_active: number | boolean }) {
    const user = await this.users.setStatus(id, body.is_active ? 1 : 0);
    return { ok: true, user };
  }
}