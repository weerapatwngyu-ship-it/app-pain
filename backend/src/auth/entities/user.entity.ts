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

  // `type: 'varchar'` is required on every nullable-`string` column below —
  // TypeScript's emitted reflection metadata for a `string | null` union
  // collapses to `Object`, and TypeORM can't map `Object` to a postgres
  // column type without an explicit hint.
  @Column({ type: 'varchar', unique: true, nullable: true })
  email: string | null;

  @Column({ type: 'varchar', nullable: true })
  passwordHash: string | null;

  // Phone-based accounts (OTP + PIN login) don't have a password —
  // `email`/`passwordHash` stay null for those rows.
  @Column({ type: 'varchar', unique: true, nullable: true })
  phone: string | null;

  @Column({ type: 'varchar', nullable: true })
  pinHash: string | null;

  @Column({ default: false })
  consentHealth: boolean;

  @Column({ default: false })
  consentMarketing: boolean;

  @Column({ type: 'varchar', nullable: true })
  avatarUrl: string | null;

  @Column()
  name: string;

  @Column({ type: 'enum', enum: UserRole })
  role: UserRole;

  @Column({ type: 'timestamptz', default: () => 'now()' })
  createdAt: Date;
}
