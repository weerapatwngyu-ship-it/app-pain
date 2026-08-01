import { ConflictException, Injectable, Logger, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { InjectRepository } from '@nestjs/typeorm';
import * as bcrypt from 'bcrypt';
import { Repository } from 'typeorm';
import { Patient } from '../patients/entities/patient.entity';
import { LoginPhonePinDto } from './dto/login-phone-pin.dto';
import { LoginDto } from './dto/login.dto';
import { OtpRequestDto } from './dto/otp-request.dto';
import { OtpVerifyDto } from './dto/otp-verify.dto';
import { RegisterPhoneDto } from './dto/register-phone.dto';
import { RegisterDto } from './dto/register.dto';
import { User, UserRole } from './entities/user.entity';

const SALT_ROUNDS = 12;
const OTP_TTL_MS = 15 * 60 * 1000;
// Generous window between OTP verification and finishing registration —
// this is dev/local testing, not a production SMS flow under time
// pressure, so err toward not making people re-verify mid-signup.
const OTP_VERIFIED_TTL_MS = 60 * 60 * 1000;

interface OtpRecord {
  otp: string;
  refCode: string;
  expiresAt: number;
  verifiedAt: number | null;
}

@Injectable()
export class AuthService {
  private readonly logger = new Logger(AuthService.name);

  // In-memory OTP store — fine for a single dev/staging instance. Swap for
  // Redis (and a real SMS gateway in `sendOtp`) before running more than one
  // backend instance or going to production.
  private readonly otpStore = new Map<string, OtpRecord>();

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
    if (!user || !user.passwordHash || !(await bcrypt.compare(dto.password, user.passwordHash))) {
      throw new UnauthorizedException('Invalid email or password');
    }
    return this.issueTokens(user);
  }

  /** Generates and "sends" a 6-digit OTP for `phone` — no SMS gateway is
   * wired up yet, so it's logged server-side instead. Swap the logger call
   * for a real provider (Twilio/etc) once credentials exist; the rest of
   * the flow (ref code, TTL, verify) stays the same. */
  requestOtp(dto: OtpRequestDto) {
    const otp = String(Math.floor(100000 + Math.random() * 900000));
    const refCode = Math.random().toString(36).slice(2, 6);
    this.otpStore.set(dto.phone, {
      otp,
      refCode,
      expiresAt: Date.now() + OTP_TTL_MS,
      verifiedAt: null,
    });
    this.logger.log(`OTP for ${dto.phone}: ${otp} (ref ${refCode})`);
    return {
      refCode,
      expiresInSeconds: OTP_TTL_MS / 1000,
      ...(process.env.NODE_ENV !== 'production' ? { devOtp: otp } : {}),
    };
  }

  async verifyOtp(dto: OtpVerifyDto) {
    const record = this.otpStore.get(dto.phone);
    if (!record || record.expiresAt < Date.now()) {
      throw new UnauthorizedException('รหัส OTP หมดอายุ กรุณาขอรหัสใหม่');
    }
    if (record.otp !== dto.otp) {
      throw new UnauthorizedException('รหัส OTP ไม่ถูกต้อง');
    }
    record.verifiedAt = Date.now();

    const existing = await this.users.findOne({ where: { phone: dto.phone } });
    return { verified: true, isNewUser: !existing };
  }

  private assertPhoneRecentlyVerified(phone: string) {
    const record = this.otpStore.get(phone);
    if (!record || !record.verifiedAt || Date.now() - record.verifiedAt > OTP_VERIFIED_TTL_MS) {
      throw new UnauthorizedException('กรุณายืนยันเบอร์โทรศัพท์ด้วย OTP ก่อน');
    }
  }

  async registerWithPhone(dto: RegisterPhoneDto) {
    this.assertPhoneRecentlyVerified(dto.phone);

    const existingPhone = await this.users.findOne({ where: { phone: dto.phone } });
    if (existingPhone) throw new ConflictException('เบอร์โทรศัพท์นี้ถูกใช้สมัครสมาชิกแล้ว');
    const existingEmail = await this.users.findOne({ where: { email: dto.email } });
    if (existingEmail) throw new ConflictException('อีเมลนี้ถูกใช้สมัครสมาชิกแล้ว');

    const pinHash = await bcrypt.hash(dto.pin, SALT_ROUNDS);
    const name = `${dto.firstName} ${dto.lastName}`.trim();
    const user = await this.users.save(
      this.users.create({
        phone: dto.phone,
        pinHash,
        email: dto.email,
        name,
        role: UserRole.PATIENT,
        consentHealth: dto.consentHealth,
        consentMarketing: dto.consentMarketing,
      }),
    );

    await this.patients.save(
      this.patients.create({
        ownerUserId: user.id,
        name,
        birthDate: dto.birthDate,
        gender: dto.gender,
      }),
    );

    this.otpStore.delete(dto.phone);
    return this.issueTokens(user);
  }

  async loginWithPhonePin(dto: LoginPhonePinDto) {
    const user = await this.users.findOne({ where: { phone: dto.phone } });
    if (!user || !user.pinHash || !(await bcrypt.compare(dto.pin, user.pinHash))) {
      throw new UnauthorizedException('เบอร์โทรศัพท์หรือรหัส PIN ไม่ถูกต้อง');
    }
    return this.issueTokens(user);
  }

  private async issueTokens(user: User) {
    const payload = { sub: user.id, email: user.email, role: user.role };
    const patientId = await this.findOwnPatientId(user);
    return {
      accessToken: this.jwt.sign(payload),
      user: {
        id: user.id,
        email: user.email,
        name: user.name,
        role: user.role,
        patientId,
        phone: user.phone,
      },
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
