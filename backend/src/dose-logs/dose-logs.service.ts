import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { DoseSchedule } from '../prescriptions/entities/dose-schedule.entity';
import { Prescription } from '../prescriptions/entities/prescription.entity';
import { CreateDoseLogDto } from './dto/create-dose-log.dto';
import { DoseLog } from './entities/dose-log.entity';

@Injectable()
export class DoseLogsService {
  constructor(
    @InjectRepository(DoseLog) private readonly doseLogs: Repository<DoseLog>,
    @InjectRepository(DoseSchedule) private readonly schedules: Repository<DoseSchedule>,
    @InjectRepository(Prescription) private readonly prescriptions: Repository<Prescription>,
  ) {}

  /** A dose log names a schedule, not a patient — resolve which patient the
   * schedule belongs to so the caller's access to it can be checked. */
  async patientIdForSchedule(scheduleId: string): Promise<string> {
    const schedule = await this.schedules.findOne({ where: { id: scheduleId } });
    if (!schedule) throw new NotFoundException('ไม่พบตารางยานี้');
    const prescription = await this.prescriptions.findOne({
      where: { id: schedule.prescriptionId },
    });
    if (!prescription) throw new NotFoundException('ไม่พบใบสั่งยาของตารางยานี้');
    return prescription.patientId;
  }

  create(dto: CreateDoseLogDto) {
    return this.doseLogs.save(
      this.doseLogs.create({
        ...dto,
        actionedAt: dto.actionedAt ? new Date(dto.actionedAt) : new Date(),
      }),
    );
  }

  findByPatientSchedules(scheduleIds: string[]) {
    if (scheduleIds.length === 0) return Promise.resolve([]);
    return this.doseLogs
      .createQueryBuilder('log')
      .where('log.scheduleId IN (:...ids)', { ids: scheduleIds })
      .orderBy('log.scheduledAt', 'DESC')
      .getMany();
  }
}
