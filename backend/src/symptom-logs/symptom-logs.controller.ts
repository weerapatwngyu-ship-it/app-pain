import { Body, Controller, Get, Param, Post, Query, UseGuards } from '@nestjs/common';
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

  @Get('patients/:id/symptom-logs')
  findAll(@Param('id') patientId: string, @Query('category') category?: string) {
    return this.symptomLogsService.findAll(patientId, category);
  }

  @Get('patients/:id/symptom-logs/category-counts')
  categoryCounts(@Param('id') patientId: string) {
    return this.symptomLogsService.countByCategory(patientId);
  }

  @Get('patients/:id/trends')
  trends(@Param('id') patientId: string) {
    return this.symptomLogsService.trends(patientId);
  }
}
