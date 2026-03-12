import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AttendanceEntity } from './attendance.entity';
import { AttendanceController } from './attendance.controller';
import { AttendanceService } from './attendance.service';
import { ApprovalEntity } from '../approvals/approval.entity';
import { GeoModule } from '../geo/geo.module';

@Module({
  imports: [TypeOrmModule.forFeature([AttendanceEntity, ApprovalEntity]), 
  GeoModule,],
  controllers: [AttendanceController],
  providers: [AttendanceService],
})
export class AttendanceModule {}