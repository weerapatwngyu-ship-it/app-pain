import { IsEnum, IsNumber, IsUUID } from 'class-validator';
import { AlertRuleMetric } from '../entities/alert-rule.entity';

export class CreateAlertRuleDto {
  @IsUUID()
  patientId: string;

  @IsEnum(AlertRuleMetric)
  metric: AlertRuleMetric;

  @IsNumber()
  threshold: number;
}
