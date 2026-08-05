import { Body, Controller, Get, Param, Post, Query, UseGuards } from '@nestjs/common';
import { AuthUser, CurrentUser } from '../common/current-user.decorator';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { PatientsService } from '../patients/patients.service';
import { CreateSymptomLogDto } from './dto/create-symptom-log.dto';
import { SymptomLogsService } from './symptom-logs.service';

@UseGuards(JwtAuthGuard)
@Controller()
export class SymptomLogsController {
  constructor(
    private readonly symptomLogsService: SymptomLogsService,
    private readonly patientsService: PatientsService,
  ) {}

  @Post('symptom-logs')
  async create(@CurrentUser() user: AuthUser, @Body() dto: CreateSymptomLogDto) {
    await this.patientsService.assertCanAccess(dto.patientId, user.userId);
    return this.symptomLogsService.create(dto);
  }

  @Get('patients/:id/symptom-logs')
  async findAll(
    @CurrentUser() user: AuthUser,
    @Param('id') patientId: string,
    @Query('category') category?: string,
  ) {
    await this.patientsService.assertCanAccess(patientId, user.userId);
    return this.symptomLogsService.findAll(patientId, category);
  }

  @Get('patients/:id/symptom-logs/category-counts')
  async categoryCounts(@CurrentUser() user: AuthUser, @Param('id') patientId: string) {
    await this.patientsService.assertCanAccess(patientId, user.userId);
    return this.symptomLogsService.countByCategory(patientId);
  }

  @Get('patients/:id/trends')
  async trends(@CurrentUser() user: AuthUser, @Param('id') patientId: string) {
    await this.patientsService.assertCanAccess(patientId, user.userId);
    return this.symptomLogsService.trends(patientId);
  }
}
