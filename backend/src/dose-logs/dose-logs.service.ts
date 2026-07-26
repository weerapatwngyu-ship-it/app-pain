import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { CreateDoseLogDto } from './dto/create-dose-log.dto';
import { DoseLog } from './entities/dose-log.entity';

@Injectable()
export class DoseLogsService {
  constructor(@InjectRepository(DoseLog) private readonly doseLogs: Repository<DoseLog>) {}

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
