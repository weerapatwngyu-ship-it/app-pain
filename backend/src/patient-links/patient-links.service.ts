import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { CreatePatientLinkDto } from './dto/create-patient-link.dto';
import { PatientLink, PatientLinkStatus } from './entities/patient-link.entity';

@Injectable()
export class PatientLinksService {
  constructor(@InjectRepository(PatientLink) private readonly links: Repository<PatientLink>) {}

  create(dto: CreatePatientLinkDto) {
    return this.links.save(
      this.links.create({ ...dto, status: PatientLinkStatus.PENDING }),
    );
  }

  async acknowledge(id: string) {
    const link = await this.links.findOne({ where: { id } });
    if (!link) throw new NotFoundException('Patient link not found');
    link.status = PatientLinkStatus.ACTIVE;
    return this.links.save(link);
  }

  async revoke(id: string) {
    const link = await this.links.findOne({ where: { id } });
    if (!link) throw new NotFoundException('Patient link not found');
    link.status = PatientLinkStatus.REVOKED;
    return this.links.save(link);
  }
}
