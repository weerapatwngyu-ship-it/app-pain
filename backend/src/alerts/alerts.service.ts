import { ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { In, Repository } from 'typeorm';
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

  /** Scoped to the patients the caller may see — an unscoped listing would
   * hand every user the whole system's alerts. */
  findByStatusForPatients(patientIds: string[], status?: AlertStatus) {
    if (patientIds.length === 0) return Promise.resolve([]);
    return this.alerts.find({
      where: status
        ? { status, patientId: In(patientIds) }
        : { patientId: In(patientIds) },
      order: { createdAt: 'DESC' },
    });
  }

  async acknowledgeForPatients(id: string, patientIds: string[]) {
    const alert = await this.alerts.findOne({ where: { id } });
    if (!alert) throw new NotFoundException('Alert not found');
    if (!patientIds.includes(alert.patientId)) {
      throw new ForbiddenException('No access to this alert');
    }
    alert.status = AlertStatus.ACKNOWLEDGED;
    return this.alerts.save(alert);
  }
}
