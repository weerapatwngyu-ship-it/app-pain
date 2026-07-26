import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { CreateAlertRuleDto } from './dto/create-alert-rule.dto';
import { AlertRule } from './entities/alert-rule.entity';
import { Alert, AlertStatus } from './entities/alert.entity';

@Injectable()
export class AlertsService {
  constructor(
    @InjectRepository(Alert) private readonly alerts: Repository<Alert>,
    @InjectRepository(AlertRule) private readonly alertRules: Repository<AlertRule>,
  ) {}

  createRule(dto: CreateAlertRuleDto) {
    return this.alertRules.save(this.alertRules.create(dto));
  }

  findByStatus(status?: AlertStatus) {
    return this.alerts.find({
      where: status ? { status } : {},
      order: { createdAt: 'DESC' },
    });
  }

  async acknowledge(id: string) {
    const alert = await this.alerts.findOne({ where: { id } });
    if (!alert) throw new NotFoundException('Alert not found');
    alert.status = AlertStatus.ACKNOWLEDGED;
    return this.alerts.save(alert);
  }
}
