import { Body, Controller, Post, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { AuthUser, CurrentUser } from '../common/current-user.decorator';
import { PatientsService } from '../patients/patients.service';
import { CreateDoseLogDto } from './dto/create-dose-log.dto';
import { DoseLogsService } from './dose-logs.service';

@UseGuards(JwtAuthGuard)
@Controller('dose-logs')
export class DoseLogsController {
  constructor(
    private readonly doseLogsService: DoseLogsService,
    private readonly patientsService: PatientsService,
  ) {}

  @Post()
  async create(@CurrentUser() user: AuthUser, @Body() dto: CreateDoseLogDto) {
    const patientId = await this.doseLogsService.patientIdForSchedule(dto.scheduleId);
    await this.patientsService.assertCanAccess(patientId, user.userId);
    return this.doseLogsService.create(dto);
  }
}
