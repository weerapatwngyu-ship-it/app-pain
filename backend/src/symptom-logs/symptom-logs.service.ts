import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { DoseLog } from '../dose-logs/entities/dose-log.entity';
import { DoseSchedule } from '../prescriptions/entities/dose-schedule.entity';
import { Prescription } from '../prescriptions/entities/prescription.entity';
import { CreateSymptomLogDto } from './dto/create-symptom-log.dto';
import { SymptomLog } from './entities/symptom-log.entity';

@Injectable()
export class SymptomLogsService {
  constructor(
    @InjectRepository(SymptomLog) private readonly symptomLogs: Repository<SymptomLog>,
    @InjectRepository(Prescription) private readonly prescriptions: Repository<Prescription>,
    @InjectRepository(DoseSchedule) private readonly schedules: Repository<DoseSchedule>,
    @InjectRepository(DoseLog) private readonly doseLogs: Repository<DoseLog>,
  ) {}

  create(dto: CreateSymptomLogDto) {
    return this.symptomLogs.save(this.symptomLogs.create(dto));
  }

  async trends(patientId: string) {
    const symptoms = await this.symptomLogs.find({
      where: { patientId },
      order: { recordedAt: 'ASC' },
    });

    const prescriptions = await this.prescriptions.find({ where: { patientId } });
    const prescriptionIds = prescriptions.map((p) => p.id);

    let doseLogEntries: DoseLog[] = [];
    if (prescriptionIds.length > 0) {
      const schedules = await this.schedules
        .createQueryBuilder('schedule')
        .where('schedule.prescriptionId IN (:...ids)', { ids: prescriptionIds })
        .getMany();
      const scheduleIds = schedules.map((s) => s.id);
      if (scheduleIds.length > 0) {
        doseLogEntries = await this.doseLogs
          .createQueryBuilder('log')
          .where('log.scheduleId IN (:...ids)', { ids: scheduleIds })
          .orderBy('log.scheduledAt', 'ASC')
          .getMany();
      }
    }

    return {
      patientId,
      symptomSeries: symptoms.map((s) => ({ recordedAt: s.recordedAt, painScore: s.painScore })),
      doseSeries: doseLogEntries.map((d) => ({
        scheduledAt: d.scheduledAt,
        actionedAt: d.actionedAt,
        status: d.status,
      })),
    };
  }
}
