import { Injectable, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcrypt';
import { GeoService } from '../geo/geo.service';
import { UsersService } from '../users/users.service';

@Injectable()
export class AuthService {
  constructor(
    private readonly jwt: JwtService,
    private readonly users: UsersService,
    private readonly geo: GeoService,
  ) {}

  private async buildAuthPayload(userId: number) {
    const user = await this.users.findById(userId);
    if (!user || !user.is_active) throw new UnauthorizedException('User is inactive or missing');
    const territory_ids = await this.geo.getUserTerritoryIds(user.id);
    return {
      sub: user.id,
      phone: user.phone,
      role: user.role,
      full_name: user.full_name,
      territory_ids,
    };
  }

  async login(phone: string, password: string) {
    const user = await this.users.findByPhone(phone);
    if (!user || !user.is_active) {
      throw new UnauthorizedException('Invalid credentials');
    }

    const ok = await bcrypt.compare(password, user.password_hash);
    if (!ok) throw new UnauthorizedException('Invalid credentials');

    const payload = await this.buildAuthPayload(user.id);
    return {
      access_token: await this.jwt.signAsync(payload),
      user: payload,
    };
  }

  async refresh(userId: number) {
    const payload = await this.buildAuthPayload(userId);
    return {
      access_token: await this.jwt.signAsync(payload),
      user: payload,
    };
  }
}
