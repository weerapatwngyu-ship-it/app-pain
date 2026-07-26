import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { PatientLink } from './entities/patient-link.entity';
import { PatientLinksController } from './patient-links.controller';
import { PatientLinksService } from './patient-links.service';

@Module({
  imports: [TypeOrmModule.forFeature([PatientLink])],
  controllers: [PatientLinksController],
  providers: [PatientLinksService],
  exports: [TypeOrmModule],
})
export class PatientLinksModule {}
