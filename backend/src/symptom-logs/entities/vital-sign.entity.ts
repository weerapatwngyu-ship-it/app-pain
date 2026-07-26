import { Column, Entity, PrimaryGeneratedColumn } from 'typeorm';

@Entity('vital_signs')
export class VitalSign {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'uuid' })
  patientId: string;

  @Column({ type: 'timestamptz', default: () => 'now()' })
  recordedAt: Date;

  @Column({ type: 'int', nullable: true })
  heartRate?: number;

  @Column({ nullable: true })
  bloodPressure?: string;

  @Column({ type: 'float', nullable: true })
  temperature?: number;
}
