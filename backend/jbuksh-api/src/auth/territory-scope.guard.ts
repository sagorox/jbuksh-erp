import { CanActivate, ExecutionContext, Injectable, UnauthorizedException } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { GeoService } from '../geo/geo.service';
import { TERRITORY_SCOPED_KEY } from './territory-scoped.decorator';
import { Role } from './roles.enum';

@Injectable()
export class TerritoryScopeGuard implements CanActivate {
  constructor(private readonly reflector: Reflector, private readonly geo: GeoService) {}

  async canActivate(ctx: ExecutionContext): Promise<boolean> {
    const isScoped = this.reflector.getAllAndOverride<boolean>(TERRITORY_SCOPED_KEY, [
      ctx.getHandler(),
      ctx.getClass(),
    ]);

    // controller/method এ TerritoryScoped না থাকলে scope enforce করবো না
    if (!isScoped) return true;

    const req = ctx.switchToHttp().getRequest();
    const user = req.user as { sub?: number; role?: Role };

    if (!user?.sub) throw new UnauthorizedException('No user in request');

    // SUPER_ADMIN → unrestricted
    if (user.role === Role.SUPER_ADMIN) {
      req.scope = { territoryIds: null }; // null = all
      return true;
    }

    const territoryIds = await this.geo.getUserTerritoryIds(user.sub);
    req.scope = { territoryIds };

    return true;
  }
}