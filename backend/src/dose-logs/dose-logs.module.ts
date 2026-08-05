import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { PatientsModule } from '../patients/patients.module';
import { DoseSchedule } from '../prescriptions/entities/dose-schedule.entity';
import { Prescription } from '../prescriptions/entities/prescription.entity';
import { DoseLogsController } from './dose-logs.controller';
import { DoseLogsService } from './dose-logs.service';
import { DoseLog } from './entities/dose-log.entity';

@Module({
  imports: [TypeOrmModule.forFeature([DoseLog, DoseSchedule, Prescription]), PatientsModule],
  controllers: [DoseLogsController],
  providers: [DoseLogsService],
  exports: [TypeOrmModule, DoseLogsService],
})
export class DoseLogsModule {}
