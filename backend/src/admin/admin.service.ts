import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Patient } from '../patients/entities/patient.entity';
import { User } from '../auth/entities/user.entity';

@Injectable()
export class AdminService {
  constructor(
    @InjectRepository(User) private readonly users: Repository<User>,
    @InjectRepository(Patient) private readonly patients: Repository<Patient>,
  ) {}

  async listUsers() {
    const rows = await this.users.find({ order: { createdAt: 'DESC' } });
    // Never serialize passwordHash out of the API, admin view or not.
    return rows.map(({ id, email, name, role, createdAt }) => ({
      id,
      email,
      name,
      role,
      createdAt,
    }));
  }

  listPatients() {
    return this.patients.find({ order: { createdAt: 'DESC' } });
  }
}
