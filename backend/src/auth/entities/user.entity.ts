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

  @Column({ unique: true })
  email: string;

  @Column()
  passwordHash: string;

  @Column()
  name: string;

  @Column({ type: 'enum', enum: UserRole })
  role: UserRole;

  @Column({ type: 'timestamptz', default: () => 'now()' })
  createdAt: Date;
}
