import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { DoseLog } from '../dose-logs/entities/dose-log.entity';
import { DoseSchedule } from '../prescriptions/entities/dose-schedule.entity';
import { PatientsModule } from '../patients/patients.module';
import { Prescription } from '../prescriptions/entities/prescription.entity';
import { SymptomLog } from './entities/symptom-log.entity';
import { VitalSign } from './entities/vital-sign.entity';
import { SymptomLogsController } from './symptom-logs.controller';
import { SymptomLogsService } from './symptom-logs.service';

@Module({
  imports: [
    TypeOrmModule.forFeature([SymptomLog, VitalSign, Prescription, DoseSchedule, DoseLog]),
    PatientsModule,
  ],
  controllers: [SymptomLogsController],
  providers: [SymptomLogsService],
  exports: [TypeOrmModule],
})
export class SymptomLogsModule {}
