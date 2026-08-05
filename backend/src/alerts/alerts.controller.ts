import { Body, Controller, Get, Param, Post, Query, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { AuthUser, CurrentUser } from '../common/current-user.decorator';
import { PatientsService } from '../patients/patients.service';
import { CreateAlertRuleDto } from './dto/create-alert-rule.dto';
import { AlertStatus } from './entities/alert.entity';
import { AlertsService } from './alerts.service';

@UseGuards(JwtAuthGuard)
@Controller()
export class AlertsController {
  constructor(
    private readonly alertsService: AlertsService,
    private readonly patientsService: PatientsService,
  ) {}

  @Post('alert-rules')
  async createRule(@CurrentUser() user: AuthUser, @Body() dto: CreateAlertRuleDto) {
    await this.patientsService.assertCanAccess(dto.patientId, user.userId);
    return this.alertsService.createRule(dto);
  }

  @Get('alerts')
  async findAll(@CurrentUser() user: AuthUser, @Query('status') status?: AlertStatus) {
    const patientIds = await this.patientsService.accessiblePatientIds(user.userId);
    return this.alertsService.findByStatusForPatients(patientIds, status);
  }

  @Post('alerts/:id/acknowledge')
  async acknowledge(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    const patientIds = await this.patientsService.accessiblePatientIds(user.userId);
    return this.alertsService.acknowledgeForPatients(id, patientIds);
  }
}
