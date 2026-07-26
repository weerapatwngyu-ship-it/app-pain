import { Body, Controller, Get, Param, Post, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CreateSymptomLogDto } from './dto/create-symptom-log.dto';
import { SymptomLogsService } from './symptom-logs.service';

@UseGuards(JwtAuthGuard)
@Controller()
export class SymptomLogsController {
  constructor(private readonly symptomLogsService: SymptomLogsService) {}

  @Post('symptom-logs')
  create(@Body() dto: CreateSymptomLogDto) {
    return this.symptomLogsService.create(dto);
  }

  @Get('patients/:id/trends')
  trends(@Param('id') patientId: string) {
    return this.symptomLogsService.trends(patientId);
  }
}
