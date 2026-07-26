import { Column, Entity, PrimaryGeneratedColumn } from 'typeorm';

@Entity('symptom_logs')
export class SymptomLog {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'uuid' })
  patientId: string;

  @Column({ type: 'timestamptz', default: () => 'now()' })
  recordedAt: Date;

  @Column({ type: 'int' })
  painScore: number;

  @Column({ type: 'jsonb', nullable: true })
  customFields?: Record<string, unknown>;
}
