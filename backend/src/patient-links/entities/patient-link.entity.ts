import { Column, Entity, PrimaryGeneratedColumn } from 'typeorm';

export enum PatientLinkRole {
  CAREGIVER = 'caregiver',
  PROVIDER = 'provider',
}

export enum PatientLinkStatus {
  PENDING = 'pending',
  ACTIVE = 'active',
  REVOKED = 'revoked',
}

@Entity('patient_links')
export class PatientLink {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'uuid' })
  patientId: string;

  @Column({ type: 'uuid' })
  userId: string;

  @Column({ type: 'enum', enum: PatientLinkRole })
  role: PatientLinkRole;

  @Column({ type: 'enum', enum: PatientLinkStatus, default: PatientLinkStatus.PENDING })
  status: PatientLinkStatus;

  @Column({ type: 'timestamptz', default: () => 'now()' })
  createdAt: Date;
}
