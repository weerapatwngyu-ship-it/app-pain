import { ForbiddenException, NotFoundException } from '@nestjs/common';
import { getRepositoryToken } from '@nestjs/typeorm';
import { Test } from '@nestjs/testing';
import { Repository } from 'typeorm';
import { PatientLink, PatientLinkStatus } from '../patient-links/entities/patient-link.entity';
import { Patient } from './entities/patient.entity';
import { PatientsService } from './patients.service';

describe('PatientsService access control', () => {
  let service: PatientsService;
  let patients: jest.Mocked<Repository<Patient>>;
  let links: jest.Mocked<Repository<PatientLink>>;

  const owner = 'user-owner';
  const stranger = 'user-stranger';
  const caregiver = 'user-caregiver';

  const patient: Patient = {
    id: 'patient-1',
    ownerUserId: owner,
    name: 'Somchai',
    birthDate: '2000-01-01',
    createdAt: new Date(),
  };

  beforeEach(async () => {
    const moduleRef = await Test.createTestingModule({
      providers: [
        PatientsService,
        {
          provide: getRepositoryToken(Patient),
          useValue: { findOne: jest.fn(), find: jest.fn(), create: jest.fn(), save: jest.fn() },
        },
        {
          provide: getRepositoryToken(PatientLink),
          useValue: { findOne: jest.fn(), find: jest.fn() },
        },
      ],
    }).compile();

    service = moduleRef.get(PatientsService);
    patients = moduleRef.get(getRepositoryToken(Patient));
    links = moduleRef.get(getRepositoryToken(PatientLink));
  });

  describe('assertCanAccess', () => {
    it('allows the owner', async () => {
      patients.findOne.mockResolvedValue(patient);

      await expect(service.assertCanAccess(patient.id, owner)).resolves.toBeUndefined();
    });

    it('allows a caregiver with an active link', async () => {
      patients.findOne.mockResolvedValue(patient);
      links.findOne.mockResolvedValue({ id: 'link-1' } as PatientLink);

      await expect(service.assertCanAccess(patient.id, caregiver)).resolves.toBeUndefined();
    });

    it('rejects a stranger who knows the patient id', async () => {
      patients.findOne.mockResolvedValue(patient);
      links.findOne.mockResolvedValue(null);

      await expect(service.assertCanAccess(patient.id, stranger)).rejects.toBeInstanceOf(
        ForbiddenException,
      );
    });

    it('rejects an unknown patient id', async () => {
      patients.findOne.mockResolvedValue(null);

      await expect(service.assertCanAccess('nope', owner)).rejects.toBeInstanceOf(
        NotFoundException,
      );
    });
  });

  describe('accessiblePatientIds', () => {
    it('returns owned and actively linked patients without duplicates', async () => {
      patients.find.mockResolvedValue([patient]);
      links.find.mockResolvedValue([
        { patientId: patient.id, status: PatientLinkStatus.ACTIVE } as PatientLink,
        { patientId: 'patient-2', status: PatientLinkStatus.ACTIVE } as PatientLink,
      ]);

      const ids = await service.accessiblePatientIds(owner);

      expect(ids.sort()).toEqual(['patient-1', 'patient-2']);
    });

    it('returns nothing for a user with no patients', async () => {
      patients.find.mockResolvedValue([]);
      links.find.mockResolvedValue([]);

      await expect(service.accessiblePatientIds(stranger)).resolves.toEqual([]);
    });
  });
});
