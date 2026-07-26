import { Body, Controller, Post, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CreateDoseLogDto } from './dto/create-dose-log.dto';
import { DoseLogsService } from './dose-logs.service';

@UseGuards(JwtAuthGuard)
@Controller('dose-logs')
export class DoseLogsController {
  constructor(private readonly doseLogsService: DoseLogsService) {}

  @Post()
  create(@Body() dto: CreateDoseLogDto) {
    return this.doseLogsService.create(dto);
  }
}
