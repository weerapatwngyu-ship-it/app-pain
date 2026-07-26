import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { CreatePrescriptionDto } from './dto/create-prescription.dto';
import { DoseSchedule } from './entities/dose-schedule.entity';
import { Prescription } from './entities/prescription.entity';

@Injectable()
export class PrescriptionsService {
  constructor(
    @InjectRepository(Prescription) private readonly prescriptions: Repository<Prescription>,
    @InjectRepository(DoseSchedule) private readonly schedules: Repository<DoseSchedule>,
  ) {}

  async create(dto: CreatePrescriptionDto) {
    const { schedule, ...prescriptionData } = dto;
    const prescription = await this.prescriptions.save(
      this.prescriptions.create(prescriptionData),
    );
    const doseSchedules = await this.schedules.save(
      schedule.map((s) =>
        this.schedules.create({
          prescriptionId: prescription.id,
          scheduledTime: s.scheduledTime,
          isPrn: s.isPrn ?? false,
        }),
      ),
    );
    return { ...prescription, schedule: doseSchedules };
  }

  async update(id: string, dto: Partial<CreatePrescriptionDto>) {
    const prescription = await this.prescriptions.findOne({ where: { id } });
    if (!prescription) throw new NotFoundException('Prescription not found');
    const { schedule, ...rest } = dto;
    Object.assign(prescription, rest);
    return this.prescriptions.save(prescription);
  }

  async todaySchedule(patientId: string) {
    const prescriptions = await this.prescriptions.find({ where: { patientId } });
    const prescriptionIds = prescriptions.map((p) => p.id);
    if (prescriptionIds.length === 0) return [];

    const schedules = await this.schedules
      .createQueryBuilder('schedule')
      .where('schedule.prescriptionId IN (:...ids)', { ids: prescriptionIds })
      .getMany();

    const prescriptionById = new Map(prescriptions.map((p) => [p.id, p]));
    return schedules.map((s) => ({
      scheduleId: s.id,
      scheduledTime: s.scheduledTime,
      isPrn: s.isPrn,
      medicationName: prescriptionById.get(s.prescriptionId)?.medicationName,
      dosage: prescriptionById.get(s.prescriptionId)?.dosage,
    }));
  }
}
