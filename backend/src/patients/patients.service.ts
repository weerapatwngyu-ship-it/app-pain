import { ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { PatientLink, PatientLinkStatus } from '../patient-links/entities/patient-link.entity';
import { CreatePatientDto } from './dto/create-patient.dto';
import { Patient } from './entities/patient.entity';

@Injectable()
export class PatientsService {
  constructor(
    @InjectRepository(Patient) private readonly patients: Repository<Patient>,
    @InjectRepository(PatientLink) private readonly links: Repository<PatientLink>,
  ) {}

  create(ownerUserId: string, dto: CreatePatientDto) {
    return this.patients.save(this.patients.create({ ...dto, ownerUserId }));
  }

  async findOne(patientId: string, requestUserId: string): Promise<Patient> {
    const patient = await this.patients.findOne({ where: { id: patientId } });
    if (!patient) throw new NotFoundException('Patient not found');
    await this.assertAccess(patient, requestUserId);
    return patient;
  }

  private async assertAccess(patient: Patient, requestUserId: string) {
    if (patient.ownerUserId === requestUserId) return;
    const link = await this.links.findOne({
      where: { patientId: patient.id, userId: requestUserId, status: PatientLinkStatus.ACTIVE },
    });
    if (!link) throw new ForbiddenException('No access to this patient');
  }
}
