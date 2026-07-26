import { Body, Controller, Get, Param, Post, Put, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { Roles } from '../common/roles.decorator';
import { RolesGuard } from '../common/roles.guard';
import { UserRole } from '../auth/entities/user.entity';
import { CreatePrescriptionDto } from './dto/create-prescription.dto';
import { PrescriptionsService } from './prescriptions.service';

@UseGuards(JwtAuthGuard, RolesGuard)
@Controller()
export class PrescriptionsController {
  constructor(private readonly prescriptionsService: PrescriptionsService) {}

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
  todaySchedule(@Param('id') patientId: string) {
    return this.prescriptionsService.todaySchedule(patientId);
  }
}
