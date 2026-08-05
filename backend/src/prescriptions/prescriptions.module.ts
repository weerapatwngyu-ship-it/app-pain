import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { PatientsModule } from '../patients/patients.module';
import { DoseSchedule } from './entities/dose-schedule.entity';
import { Prescription } from './entities/prescription.entity';
import { PrescriptionsController } from './prescriptions.controller';
import { PrescriptionsService } from './prescriptions.service';

@Module({
  imports: [TypeOrmModule.forFeature([Prescription, DoseSchedule]), PatientsModule],
  controllers: [PrescriptionsController],
  providers: [PrescriptionsService],
  exports: [TypeOrmModule],
})
export class PrescriptionsModule {}
