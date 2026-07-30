import { ConflictException, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { getRepositoryToken } from '@nestjs/typeorm';
import { Test } from '@nestjs/testing';
import * as bcrypt from 'bcrypt';
import { Repository } from 'typeorm';
import { Patient } from '../patients/entities/patient.entity';
import { AuthService } from './auth.service';
import { User, UserRole } from './entities/user.entity';

describe('AuthService', () => {
  let service: AuthService;
  let users: jest.Mocked<Repository<User>>;
  let patients: jest.Mocked<Repository<Patient>>;
  let jwt: jest.Mocked<JwtService>;

  const baseUser: User = {
    id: 'user-1',
    email: 'patient@example.com',
    passwordHash: '',
    name: 'Somchai',
    role: UserRole.PATIENT,
    createdAt: new Date(),
  };

  const basePatient: Patient = {
    id: 'patient-1',
    ownerUserId: baseUser.id,
    name: baseUser.name,
    birthDate: '2000-01-01',
    createdAt: new Date(),
  };

  beforeEach(async () => {
    const moduleRef = await Test.createTestingModule({
      providers: [
        AuthService,
        {
          provide: getRepositoryToken(User),
          useValue: {
            findOne: jest.fn(),
            create: jest.fn((data) => data),
            save: jest.fn(),
          },
        },
        {
          provide: getRepositoryToken(Patient),
          useValue: {
            findOne: jest.fn().mockResolvedValue(basePatient),
            create: jest.fn((data) => data),
            save: jest.fn().mockResolvedValue(basePatient),
          },
        },
        {
          provide: JwtService,
          useValue: { sign: jest.fn().mockReturnValue('signed-jwt') },
        },
      ],
    }).compile();

    service = moduleRef.get(AuthService);
    users = moduleRef.get(getRepositoryToken(User));
    patients = moduleRef.get(getRepositoryToken(Patient));
    jwt = moduleRef.get(JwtService);
  });

  describe('register', () => {
    it('hashes the password, creates a patient profile, and issues a token', async () => {
      users.findOne.mockResolvedValue(null);
      users.save.mockImplementation(async (data) => ({ ...baseUser, ...data }) as User);

      const result = await service.register({
        email: baseUser.email,
        password: 'super-secret',
        name: baseUser.name,
        role: UserRole.PATIENT,
      });

      expect(users.save).toHaveBeenCalled();
      const savedArg = users.save.mock.calls[0][0] as User;
      expect(savedArg.passwordHash).not.toBe('super-secret');
      expect(await bcrypt.compare('super-secret', savedArg.passwordHash)).toBe(true);

      expect(patients.save).toHaveBeenCalledWith(
        expect.objectContaining({ ownerUserId: baseUser.id, name: baseUser.name }),
      );

      expect(jwt.sign).toHaveBeenCalledWith({
        sub: baseUser.id,
        email: baseUser.email,
        role: UserRole.PATIENT,
      });
      expect(result).toEqual({
        accessToken: 'signed-jwt',
        user: {
          id: baseUser.id,
          email: baseUser.email,
          name: baseUser.name,
          role: UserRole.PATIENT,
          patientId: basePatient.id,
        },
      });
    });

    it('does not create a patient profile for non-patient roles', async () => {
      const providerUser = { ...baseUser, role: UserRole.PROVIDER };
      users.findOne.mockResolvedValue(null);
      users.save.mockImplementation(async (data) => ({ ...providerUser, ...data }) as User);

      const result = await service.register({
        email: providerUser.email,
        password: 'super-secret',
        name: providerUser.name,
        role: UserRole.PROVIDER,
      });

      expect(patients.save).not.toHaveBeenCalled();
      expect(result.user.patientId).toBeNull();
    });

    it('rejects registering an email that already exists', async () => {
      users.findOne.mockResolvedValue(baseUser);

      await expect(
        service.register({
          email: baseUser.email,
          password: 'super-secret',
          name: baseUser.name,
          role: UserRole.PATIENT,
        }),
      ).rejects.toBeInstanceOf(ConflictException);
      expect(users.save).not.toHaveBeenCalled();
    });
  });

  describe('login', () => {
    it('issues a token with the owned patientId when the password matches', async () => {
      const passwordHash = await bcrypt.hash('correct-password', 4);
      users.findOne.mockResolvedValue({ ...baseUser, passwordHash });

      const result = await service.login({ email: baseUser.email, password: 'correct-password' });

      expect(result.accessToken).toBe('signed-jwt');
      expect(result.user.email).toBe(baseUser.email);
      expect(result.user.patientId).toBe(basePatient.id);
    });

    it('rejects an unknown email', async () => {
      users.findOne.mockResolvedValue(null);

      await expect(
        service.login({ email: 'nobody@example.com', password: 'whatever' }),
      ).rejects.toBeInstanceOf(UnauthorizedException);
    });

    it('rejects the wrong password', async () => {
      const passwordHash = await bcrypt.hash('correct-password', 4);
      users.findOne.mockResolvedValue({ ...baseUser, passwordHash });

      await expect(
        service.login({ email: baseUser.email, password: 'wrong-password' }),
      ).rejects.toBeInstanceOf(UnauthorizedException);
    });
  });
});
