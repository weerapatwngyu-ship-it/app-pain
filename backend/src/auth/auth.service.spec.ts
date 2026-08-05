import { getRepositoryToken } from '@nestjs/typeorm';
import { Test } from '@nestjs/testing';
import { Repository } from 'typeorm';
import { Patient } from '../patients/entities/patient.entity';
import { AuthService } from './auth.service';
import { User, UserRole } from './entities/user.entity';

describe('AuthService', () => {
  let service: AuthService;
  let users: jest.Mocked<Repository<User>>;
  let patients: jest.Mocked<Repository<Patient>>;

  const baseUser: User = {
    id: 'user-1',
    supabaseUserId: 'supabase-abc',
    email: 'patient@example.com',
    passwordHash: null,
    phone: null,
    pinHash: null,
    consentHealth: false,
    consentMarketing: false,
    avatarUrl: null,
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
            save: jest.fn(async (data) => ({ ...baseUser, ...data }) as User),
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
      ],
    }).compile();

    service = moduleRef.get(AuthService);
    users = moduleRef.get(getRepositoryToken(User));
    patients = moduleRef.get(getRepositoryToken(Patient));
  });

  describe('findOrCreateFromSupabase', () => {
    it('returns the existing row for a known Supabase identity', async () => {
      users.findOne.mockResolvedValue(baseUser);

      const user = await service.findOrCreateFromSupabase({
        supabaseUserId: 'supabase-abc',
        email: baseUser.email,
        name: baseUser.name,
      });

      expect(user).toBe(baseUser);
      expect(users.save).not.toHaveBeenCalled();
    });

    it('creates a patient-role user and profile on first sign-in', async () => {
      users.findOne.mockResolvedValue(null);

      const user = await service.findOrCreateFromSupabase({
        supabaseUserId: 'supabase-new',
        email: 'new@example.com',
        name: 'Malee',
      });

      const savedArg = users.save.mock.calls[0][0] as User;
      expect(savedArg.supabaseUserId).toBe('supabase-new');
      expect(savedArg.role).toBe(UserRole.PATIENT);
      expect(savedArg.name).toBe('Malee');
      expect(patients.save).toHaveBeenCalledWith(
        expect.objectContaining({ ownerUserId: user.id }),
      );
    });

    it('adopts a pre-migration account that matches on email', async () => {
      const legacy = { ...baseUser, supabaseUserId: null };
      users.findOne.mockResolvedValueOnce(null).mockResolvedValueOnce(legacy);

      await service.findOrCreateFromSupabase({
        supabaseUserId: 'supabase-abc',
        email: baseUser.email,
        name: baseUser.name,
      });

      const savedArg = users.save.mock.calls[0][0] as User;
      expect(savedArg.id).toBe(baseUser.id);
      expect(savedArg.supabaseUserId).toBe('supabase-abc');
      expect(patients.save).not.toHaveBeenCalled();
    });

    it('falls back to the email local part when Google sends no name', async () => {
      users.findOne.mockResolvedValue(null);

      await service.findOrCreateFromSupabase({
        supabaseUserId: 'supabase-noname',
        email: 'somchai@example.com',
        name: null,
      });

      const savedArg = users.save.mock.calls[0][0] as User;
      expect(savedArg.name).toBe('somchai');
    });
  });

  describe('currentUser', () => {
    it('reports the owned patient id so the app can call patient routes', async () => {
      users.findOne.mockResolvedValue(baseUser);

      const result = await service.currentUser(baseUser.id);

      expect(result.user).toEqual({
        id: baseUser.id,
        email: baseUser.email,
        name: baseUser.name,
        role: UserRole.PATIENT,
        patientId: basePatient.id,
        phone: null,
        avatarUrl: null,
      });
    });
  });
});
