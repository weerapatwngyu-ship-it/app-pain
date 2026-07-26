import { Column, Entity, PrimaryGeneratedColumn } from 'typeorm';

export enum DoseLogStatus {
  TAKEN = 'taken',
  SKIPPED = 'skipped',
  SNOOZED = 'snoozed',
  MISSED = 'missed',
}

@Entity('dose_logs')
export class DoseLog {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'uuid' })
  scheduleId: string;

  @Column({ type: 'timestamptz' })
  scheduledAt: Date;

  @Column({ type: 'timestamptz', nullable: true })
  actionedAt?: Date;

  @Column({ type: 'enum', enum: DoseLogStatus })
  status: DoseLogStatus;
}
