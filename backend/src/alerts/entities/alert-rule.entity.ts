import { Column, Entity, PrimaryGeneratedColumn } from 'typeorm';

export enum AlertRuleMetric {
  MISSED_DOSES_STREAK = 'missed_doses_streak',
  PAIN_SCORE_ABOVE = 'pain_score_above',
  HEART_RATE_ABOVE = 'heart_rate_above',
  HEART_RATE_BELOW = 'heart_rate_below',
}

@Entity('alert_rules')
export class AlertRule {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'uuid' })
  patientId: string;

  @Column({ type: 'enum', enum: AlertRuleMetric })
  metric: AlertRuleMetric;

  @Column({ type: 'float' })
  threshold: number;

  @Column({ default: true })
  active: boolean;
}
