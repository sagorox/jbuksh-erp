import { Body, Controller, Get, Param, Patch, Post, Query, Req, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { RolesGuard } from '../auth/roles.guard';
import { Roles } from '../auth/roles.decorator';
import { Role } from '../auth/roles.enum';
import { TerritoryScoped } from '../auth/territory-scoped.decorator';
import { TerritoryScopeGuard } from '../auth/territory-scope.guard';
import { ExpensesService } from './expenses.service';

@Controller('api/v1/expenses')
@UseGuards(JwtAuthGuard, RolesGuard, TerritoryScopeGuard)
@TerritoryScoped()
export class ExpensesController {
  constructor(private readonly expenses: ExpensesService) {}

  // Heads
  @Post('heads')
  @Roles(Role.SUPER_ADMIN, Role.ACCOUNTING, Role.RSM)
  createHead(@Body() body: { name: string }) {
    return this.expenses.createHead(body.name);
  }

  @Get('heads')
  listHeads(@Query('activeOnly') activeOnly?: string) {
    const only = activeOnly === undefined ? true : activeOnly !== '0';
    return this.expenses.listHeads(only);
  }

  @Patch('heads/:id/status')
  @Roles(Role.SUPER_ADMIN, Role.ACCOUNTING, Role.RSM)
  toggleHead(@Param('id') id: string, @Body() body: { is_active: number }) {
    return this.expenses.toggleHead(Number(id), body.is_active);
  }

  // Expenses
  @Post()
  @Roles(Role.SUPER_ADMIN, Role.MPO, Role.RSM, Role.ACCOUNTING)
  createExpense(
    @Req() req: any,
    @Body()
    body: {
      territory_id: number;
      expense_date: string;
      head_id: number;
      amount: number;
      note?: string | null;
    },
  ) {
    const user_id = req.user.sub;
    return this.expenses.createExpense({ user_id, ...body });
  }

  @Get()
  @Roles(Role.SUPER_ADMIN, Role.RSM, Role.ACCOUNTING, Role.MPO)
  listExpenses(
    @Query('from') from?: string,
    @Query('to') to?: string,
    @Query('territory_id') territory_id?: string,
    @Query('user_id') user_id?: string,
  ) {
    return this.expenses.listExpenses({
      from,
      to,
      territory_id: territory_id ? Number(territory_id) : undefined,
      user_id: user_id ? Number(user_id) : undefined,
    });
  }

  @Post(':id/submit')
  @Roles(Role.SUPER_ADMIN, Role.MPO, Role.RSM, Role.ACCOUNTING)
  submit(@Req() req: any, @Param('id') id: string) {
    return this.expenses.submit(Number(id), req.user, req.scope);
  }
}