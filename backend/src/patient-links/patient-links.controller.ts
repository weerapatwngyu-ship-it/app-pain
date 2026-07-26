import { Body, Controller, Delete, Param, Post, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CreatePatientLinkDto } from './dto/create-patient-link.dto';
import { PatientLinksService } from './patient-links.service';

@UseGuards(JwtAuthGuard)
@Controller('patient-links')
export class PatientLinksController {
  constructor(private readonly patientLinksService: PatientLinksService) {}

  @Post()
  create(@Body() dto: CreatePatientLinkDto) {
    return this.patientLinksService.create(dto);
  }

  @Post(':id/acknowledge')
  acknowledge(@Param('id') id: string) {
    return this.patientLinksService.acknowledge(id);
  }

  @Delete(':id')
  revoke(@Param('id') id: string) {
    return this.patientLinksService.revoke(id);
  }
}
