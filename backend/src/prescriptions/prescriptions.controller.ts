import { Body, Controller, Get, Param, Post, Put, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { AuthUser, CurrentUser } from '../common/current-user.decorator';
import { Roles } from '../common/roles.decorator';
import { RolesGuard } from '../common/roles.guard';
import { UserRole } from '../auth/entities/user.entity';
import { PatientsService } from '../patients/patients.service';
import { CreatePrescriptionDto } from './dto/create-prescription.dto';
import { PrescriptionsService } from './prescriptions.service';

@UseGuards(JwtAuthGuard, RolesGuard)
@Controller()
export class PrescriptionsController {
  constructor(
    private readonly prescriptionsService: PrescriptionsService,
    private readonly patientsService: PatientsService,
  ) {}

  @Post('prescriptions')
  @Roles(UserRole.PROVIDER, UserRole.ADMIN)
  create(@Body() dto: CreatePrescriptionDto) {
    return this.prescriptionsService.create(dto);
  }

  @Put('prescriptions/:id')
  @Roles(UserRole.PROVIDER, UserRole.ADMIN)
  update(@Param('id') id: string, @Body() dto: Partial<CreatePrescriptionDto>) {
    return this.prescriptionsService.update(id, dto);
  }

  @Get('patients/:id/schedule/today')
  async todaySchedule(@CurrentUser() user: AuthUser, @Param('id') patientId: string) {
    await this.patientsService.assertCanAccess(patientId, user.userId);
    return this.prescriptionsService.todaySchedule(patientId);
  }
}
