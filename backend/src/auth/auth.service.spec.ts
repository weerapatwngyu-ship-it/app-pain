import { ConflictException, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { getRepositoryToken } from '@nestjs/typeorm';
import { Test } from '@nestjs/testing';
import * as bcrypt from 'bcrypt';
import { Repository } from 'typeorm';
import { AuthService } from './auth.service';
import { User, UserRole } from './entities/user.entity';

describe('AuthService', () => {
  let service: AuthService;
  let users: jest.Mocked<Repository<User>>;
  let jwt: jest.Mocked<JwtService>;

  const baseUser: User = {
    id: 'user-1',
    email: 'patient@example.com',
    passwordHash: '',
    name: 'Somchai',
    role: UserRole.PATIENT,
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
          provide: JwtService,
          useValue: { sign: jest.fn().mockReturnValue('signed-jwt') },
        },
      ],
    }).compile();

    service = moduleRef.get(AuthService);
    users = moduleRef.get(getRepositoryToken(User));
    jwt = moduleRef.get(JwtService);
  });

  describe('register', () => {
    it('hashes the password and issues a token for a new user', async () => {
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

      expect(jwt.sign).toHaveBeenCalledWith({
        sub: baseUser.id,
        email: baseUser.email,
        role: UserRole.PATIENT,
      });
      expect(result).toEqual({
        accessToken: 'signed-jwt',
        user: { id: baseUser.id, email: baseUser.email, name: baseUser.name, role: UserRole.PATIENT },
      });
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
    it('issues a token when the password matches', async () => {
      const passwordHash = await bcrypt.hash('correct-password', 4);
      users.findOne.mockResolvedValue({ ...baseUser, passwordHash });

      const result = await service.login({ email: baseUser.email, password: 'correct-password' });

      expect(result.accessToken).toBe('signed-jwt');
      expect(result.user.email).toBe(baseUser.email);
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
