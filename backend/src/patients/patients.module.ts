import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { PatientLinksModule } from '../patient-links/patient-links.module';
import { Patient } from './entities/patient.entity';
import { PatientsController } from './patients.controller';
import { PatientsService } from './patients.service';

@Module({
  imports: [TypeOrmModule.forFeature([Patient]), PatientLinksModule],
  controllers: [PatientsController],
  providers: [PatientsService],
  exports: [TypeOrmModule],
})
export class PatientsModule {}
