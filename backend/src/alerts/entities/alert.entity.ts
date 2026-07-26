import { Column, Entity, PrimaryGeneratedColumn } from 'typeorm';

export enum AlertSeverity {
  NORMAL = 'normal',
  WATCH = 'watch',
  CRITICAL = 'critical',
}

export enum AlertStatus {
  OPEN = 'open',
  ACKNOWLEDGED = 'acknowledged',
}

@Entity('alerts')
export class Alert {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'uuid' })
  patientId: string;

  @Column({ type: 'uuid', nullable: true })
  ruleId?: string;

  @Column({ type: 'enum', enum: AlertSeverity })
  severity: AlertSeverity;

  @Column({ type: 'enum', enum: AlertStatus, default: AlertStatus.OPEN })
  status: AlertStatus;

  @Column({ nullable: true })
  message?: string;

  @Column({ type: 'timestamptz', default: () => 'now()' })
  createdAt: Date;
}
