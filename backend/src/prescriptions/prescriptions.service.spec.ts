import { NotFoundException } from '@nestjs/common';
import { getRepositoryToken } from '@nestjs/typeorm';
import { Test } from '@nestjs/testing';
import { Repository } from 'typeorm';
import { CreatePrescriptionDto } from './dto/create-prescription.dto';
import { DoseSchedule } from './entities/dose-schedule.entity';
import { Prescription } from './entities/prescription.entity';
import { PrescriptionsService } from './prescriptions.service';

describe('PrescriptionsService', () => {
  let service: PrescriptionsService;
  let prescriptions: jest.Mocked<Repository<Prescription>>;
  let schedules: jest.Mocked<Repository<DoseSchedule>>;

  beforeEach(async () => {
    const moduleRef = await Test.createTestingModule({
      providers: [
        PrescriptionsService,
        {
          provide: getRepositoryToken(Prescription),
          useValue: {
            create: jest.fn((data) => data),
            save: jest.fn(),
            find: jest.fn(),
            findOne: jest.fn(),
          },
        },
        {
          provide: getRepositoryToken(DoseSchedule),
          useValue: {
            create: jest.fn((data) => data),
            save: jest.fn(),
            createQueryBuilder: jest.fn(),
          },
        },
      ],
    }).compile();

    service = moduleRef.get(PrescriptionsService);
    prescriptions = moduleRef.get(getRepositoryToken(Prescription));
    schedules = moduleRef.get(getRepositoryToken(DoseSchedule));
  });

  describe('create', () => {
    it('saves the prescription and generates a dose schedule for each entry', async () => {
      const dto: CreatePrescriptionDto = {
        patientId: 'patient-1',
        medicationName: 'Paracetamol',
        dosage: '500mg',
        frequency: 'twice daily',
        startDate: '2026-01-01',
        schedule: [{ scheduledTime: '08:00' }, { scheduledTime: '20:00', isPrn: true }],
      };

      prescriptions.save.mockResolvedValue({ id: 'rx-1' } as Prescription);
      (schedules.save as unknown as jest.Mock).mockResolvedValue([
        { id: 'sched-1', prescriptionId: 'rx-1', scheduledTime: '08:00', isPrn: false },
        { id: 'sched-2', prescriptionId: 'rx-1', scheduledTime: '20:00', isPrn: true },
      ] as DoseSchedule[]);

      const result = await service.create(dto);

      expect(prescriptions.save).toHaveBeenCalledWith(
        expect.objectContaining({ medicationName: 'Paracetamol', patientId: 'patient-1' }),
      );
      expect(schedules.save).toHaveBeenCalledWith([
        expect.objectContaining({ prescriptionId: 'rx-1', scheduledTime: '08:00', isPrn: false }),
        expect.objectContaining({ prescriptionId: 'rx-1', scheduledTime: '20:00', isPrn: true }),
      ]);
      expect(result.schedule).toHaveLength(2);
    });
  });

  describe('update', () => {
    it('throws when the prescription does not exist', async () => {
      prescriptions.findOne.mockResolvedValue(null);

      await expect(service.update('missing-id', { dosage: '1000mg' })).rejects.toBeInstanceOf(
        NotFoundException,
      );
    });

    it('applies partial updates to an existing prescription', async () => {
      const existing = { id: 'rx-1', dosage: '500mg' } as Prescription;
      prescriptions.findOne.mockResolvedValue(existing);
      prescriptions.save.mockImplementation(async (p) => p as Prescription);

      const result = await service.update('rx-1', { dosage: '1000mg' });

      expect(result.dosage).toBe('1000mg');
    });
  });

  describe('todaySchedule', () => {
    it('returns an empty array when the patient has no prescriptions', async () => {
      prescriptions.find.mockResolvedValue([]);

      const result = await service.todaySchedule('patient-1');

      expect(result).toEqual([]);
      expect(schedules.createQueryBuilder).not.toHaveBeenCalled();
    });

    it('joins schedules with their prescription medication details', async () => {
      prescriptions.find.mockResolvedValue([
        { id: 'rx-1', medicationName: 'Paracetamol', dosage: '500mg' } as Prescription,
      ]);
      const getMany = jest.fn().mockResolvedValue([
        { id: 'sched-1', prescriptionId: 'rx-1', scheduledTime: '08:00', isPrn: false },
      ]);
      const where = jest.fn().mockReturnValue({ getMany });
      schedules.createQueryBuilder.mockReturnValue({ where } as any);

      const result = await service.todaySchedule('patient-1');

      expect(where).toHaveBeenCalledWith('schedule.prescriptionId IN (:...ids)', {
        ids: ['rx-1'],
      });
      expect(result).toEqual([
        {
          scheduleId: 'sched-1',
          scheduledTime: '08:00',
          isPrn: false,
          medicationName: 'Paracetamol',
          dosage: '500mg',
        },
      ]);
    });
  });
});
