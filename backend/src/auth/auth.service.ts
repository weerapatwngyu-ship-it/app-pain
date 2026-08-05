import { ConflictException, Injectable, UnauthorizedException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Patient } from '../patients/entities/patient.entity';
import { UpdateProfileDto } from './dto/update-profile.dto';
import { User, UserRole } from './entities/user.entity';

/// Profile side of authentication. Credentials, sign-in and sign-up all
/// belong to Supabase Auth now; what stays here is the app's own user
/// record and the patient profile that hangs off it.
@Injectable()
export class AuthService {
  constructor(
    @InjectRepository(User) private readonly users: Repository<User>,
    @InjectRepository(Patient) private readonly patients: Repository<Patient>,
  ) {}

  async currentUser(userId: string) {
    const user = await this.users.findOne({ where: { id: userId } });
    if (!user) throw new UnauthorizedException();
    return { user: await this.toUserJson(user) };
  }

  async updateProfile(userId: string, dto: UpdateProfileDto) {
    const user = await this.users.findOne({ where: { id: userId } });
    if (!user) throw new UnauthorizedException();

    if (dto.email && dto.email !== user.email) {
      const existing = await this.users.findOne({ where: { email: dto.email } });
      if (existing) throw new ConflictException('อีเมลนี้ถูกใช้สมัครสมาชิกแล้ว');
    }

    Object.assign(user, dto);
    const saved = await this.users.save(user);
    return { user: await this.toUserJson(saved) };
  }

  /** Resolves the local user row for a Supabase identity, creating it on
   * first sign-in. Matching falls back to email so an account created
   * before this migration is adopted rather than duplicated. */
  async findOrCreateFromSupabase(identity: {
    supabaseUserId: string;
    email: string | null;
    name: string | null;
  }): Promise<User> {
    const existing = await this.users.findOne({
      where: { supabaseUserId: identity.supabaseUserId },
    });
    if (existing) return existing;

    if (identity.email) {
      const byEmail = await this.users.findOne({ where: { email: identity.email } });
      if (byEmail) {
        byEmail.supabaseUserId = identity.supabaseUserId;
        return this.users.save(byEmail);
      }
    }

    const user = await this.users.save(
      this.users.create({
        supabaseUserId: identity.supabaseUserId,
        email: identity.email,
        name: identity.name?.trim() || identity.email?.split('@')[0] || 'ผู้ใช้ใหม่',
        role: UserRole.PATIENT,
      }),
    );
    await this.createPatientProfile(user);
    return user;
  }

  async updateAvatar(userId: string, avatarUrl: string) {
    const user = await this.users.findOne({ where: { id: userId } });
    if (!user) throw new UnauthorizedException();
    user.avatarUrl = avatarUrl;
    const saved = await this.users.save(user);
    return { user: await this.toUserJson(saved) };
  }

  private async toUserJson(user: User) {
    const patientId = await this.findOwnPatientId(user);
    return {
      id: user.id,
      email: user.email,
      name: user.name,
      role: user.role,
      patientId,
      phone: user.phone,
      avatarUrl: user.avatarUrl,
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
