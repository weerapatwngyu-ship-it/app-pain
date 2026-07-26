import { Column, Entity, PrimaryGeneratedColumn } from 'typeorm';

@Entity('dose_schedules')
export class DoseSchedule {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'uuid' })
  prescriptionId: string;

  @Column({ type: 'time' })
  scheduledTime: string;

  @Column({ default: false })
  isPrn: boolean;
}
