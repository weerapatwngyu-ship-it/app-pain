import { Column, Entity, PrimaryGeneratedColumn } from 'typeorm';

@Entity('symptom_logs')
export class SymptomLog {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'uuid' })
  patientId: string;

  @Column({ type: 'timestamptz', default: () => 'now()' })
  recordedAt: Date;

  @Column({ type: 'int', nullable: true })
  painScore?: number;

  // Fixed, mobile-defined set (head/stomach/skin/respiratory/joint/other) —
  // lets the app group a patient's own logs by symptom area on the home
  // screen. Nullable so older rows without a category still work.
  @Column({ type: 'varchar', nullable: true })
  category?: string;

  @Column({ type: 'jsonb', nullable: true })
  customFields?: Record<string, unknown>;
}
