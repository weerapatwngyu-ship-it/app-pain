import { Body, Controller, Get, Param, Patch, Post, UseGuards } from '@nestjs/common';
import { AuthUser, CurrentUser } from '../common/current-user.decorator';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CreatePatientDto } from './dto/create-patient.dto';
import { UpdatePatientDto } from './dto/update-patient.dto';
import { PatientsService } from './patients.service';

@UseGuards(JwtAuthGuard)
@Controller('patients')
export class PatientsController {
  constructor(private readonly patientsService: PatientsService) {}

  @Post()
  create(@CurrentUser() user: AuthUser, @Body() dto: CreatePatientDto) {
    return this.patientsService.create(user.userId, dto);
  }

  @Get(':id')
  findOne(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.patientsService.findOne(id, user.userId);
  }

  @Patch(':id')
  update(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: UpdatePatientDto,
  ) {
    return this.patientsService.update(id, user.userId, dto);
  }
}
