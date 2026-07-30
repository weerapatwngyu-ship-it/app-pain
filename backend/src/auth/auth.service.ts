import { ConflictException, Injectable, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { InjectRepository } from '@nestjs/typeorm';
import * as bcrypt from 'bcrypt';
import { Repository } from 'typeorm';
import { Patient } from '../patients/entities/patient.entity';
import { LoginDto } from './dto/login.dto';
import { RegisterDto } from './dto/register.dto';
import { User, UserRole } from './entities/user.entity';

const SALT_ROUNDS = 12;

@Injectable()
export class AuthService {
  constructor(
    @InjectRepository(User) private readonly users: Repository<User>,
    @InjectRepository(Patient) private readonly patients: Repository<Patient>,
    private readonly jwt: JwtService,
  ) {}

  async register(dto: RegisterDto) {
    const existing = await this.users.findOne({ where: { email: dto.email } });
    if (existing) throw new ConflictException('Email already registered');

    const passwordHash = await bcrypt.hash(dto.password, SALT_ROUNDS);
    const user = await this.users.save(
      this.users.create({ email: dto.email, passwordHash, name: dto.name, role: dto.role }),
    );

    // A `patient` account is the patient — auto-create their Patient
    // profile so the mobile app has a real patientId to call
    // /patients/:id/schedule/today etc with, instead of a placeholder
    // that doesn't exist in the database. Caregiver/provider/admin
    // accounts don't own a patient profile themselves.
    if (user.role === UserRole.PATIENT) {
      await this.createPatientProfile(user);
    }

    return this.issueTokens(user);
  }

  async login(dto: LoginDto) {
    const user = await this.users.findOne({ where: { email: dto.email } });
    if (!user || !(await bcrypt.compare(dto.password, user.passwordHash))) {
      throw new UnauthorizedException('Invalid email or password');
    }
    return this.issueTokens(user);
  }

  private async issueTokens(user: User) {
    const payload = { sub: user.id, email: user.email, role: user.role };
    const patientId = await this.findOwnPatientId(user);
    return {
      accessToken: this.jwt.sign(payload),
      user: { id: user.id, email: user.email, name: user.name, role: user.role, patientId },
    };
  }

  private async findOwnPatientId(user: User): Promise<string | null> {
    if (user.role !== UserRole.PATIENT) return null;
    const existing = await this.patients.findOne({ where: { ownerUserId: user.id } });
    if (existing) return existing.id;

    // Self-heal accounts created before patient-auto-provisioning existed
    // (or by any other path that skipped it) — a patient-role user should
    // never be stuck without an owned patient profile.
    const created = await this.createPatientProfile(user);
    return created.id;
  }

  private createPatientProfile(user: User) {
    return this.patients.save(
      this.patients.create({
        ownerUserId: user.id,
        name: user.name,
        // Not collected at registration yet (Phase 2: proper onboarding
        // form) — placeholder so the NOT NULL column is satisfiable.
        birthDate: '2000-01-01',
      }),
    );
  }
}
