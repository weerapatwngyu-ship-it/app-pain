import { Body, Controller, Get, Param, Post, Query, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CreateAlertRuleDto } from './dto/create-alert-rule.dto';
import { AlertStatus } from './entities/alert.entity';
import { AlertsService } from './alerts.service';

@UseGuards(JwtAuthGuard)
@Controller()
export class AlertsController {
  constructor(private readonly alertsService: AlertsService) {}

  @Post('alert-rules')
  createRule(@Body() dto: CreateAlertRuleDto) {
    return this.alertsService.createRule(dto);
  }

  @Get('alerts')
  findAll(@Query('status') status?: AlertStatus) {
    return this.alertsService.findByStatus(status);
  }

  @Post('alerts/:id/acknowledge')
  acknowledge(@Param('id') id: string) {
    return this.alertsService.acknowledge(id);
  }
}
