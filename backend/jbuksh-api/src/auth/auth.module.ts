import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { AuthController } from './auth.controller';
import { AuthService } from './auth.service';
import { JwtStrategy } from './jwt.strategy';
import { GeoModule } from '../geo/geo.module'; // ✅ GeoModule ইমপোর্ট করা হয়েছে
import { UsersModule } from '../users/users.module'; // সাধারণত UsersModule ও প্রয়োজন হয়

@Module({
  imports: [
    ConfigModule,
    UsersModule,
    GeoModule, // ✅ imports এ যোগ করা হয়েছে
    JwtModule.registerAsync({
      imports: [ConfigModule],
      inject: [ConfigService],
      useFactory: (cfg: ConfigService) => {
        const secret = cfg.get<string>('JWT_SECRET') || 'dev_secret';
        const expiresIn = Number(cfg.get<string>('JWT_EXPIRES_IN_SECONDS') || 604800);

        return {
          secret,
          signOptions: { expiresIn }, // ✅ number (seconds)
        };
      },
    }),
  ],
  controllers: [AuthController],
  providers: [AuthService, JwtStrategy], 
})
export class AuthModule {}