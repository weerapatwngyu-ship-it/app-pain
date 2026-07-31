import { Column, Entity, PrimaryGeneratedColumn } from 'typeorm';

export enum UserRole {
  PATIENT = 'patient',
  CAREGIVER = 'caregiver',
  PROVIDER = 'provider',
  ADMIN = 'admin',
}

@Entity('users')
export class User {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ unique: true, nullable: true })
  email: string | null;

  @Column({ nullable: true })
  passwordHash: string | null;

  // Phone-based accounts (OTP + PIN login) don't have a password —
  // `email`/`passwordHash` stay null for those rows.
  @Column({ unique: true, nullable: true })
  phone: string | null;

  @Column({ nullable: true })
  pinHash: string | null;

  @Column({ default: false })
  consentHealth: boolean;

  @Column({ default: false })
  consentMarketing: boolean;

  @Column()
  name: string;

  @Column({ type: 'enum', enum: UserRole })
  role: UserRole;

  @Column({ type: 'timestamptz', default: () => 'now()' })
  createdAt: Date;
}
