import { ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { PatientLink, PatientLinkStatus } from '../patient-links/entities/patient-link.entity';
import { CreatePatientDto } from './dto/create-patient.dto';
import { UpdatePatientDto } from './dto/update-patient.dto';
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

  /** Throws unless `requestUserId` owns this patient record or has an active
   * caregiver link to it. Every endpoint that reads or writes a patient's
   * medical data must call this — a valid JWT alone only proves *who* the
   * caller is, not that they may see *this* patient. */
  async assertCanAccess(patientId: string, requestUserId: string): Promise<void> {
    await this.findOne(patientId, requestUserId);
  }

  /** Every patient this user may see: the records they own plus any they
   * have an active caregiver link to. Used to scope list endpoints that
   * would otherwise return every patient's data. */
  async accessiblePatientIds(requestUserId: string): Promise<string[]> {
    const owned = await this.patients.find({ where: { ownerUserId: requestUserId } });
    const links = await this.links.find({
      where: { userId: requestUserId, status: PatientLinkStatus.ACTIVE },
    });
    return [...new Set([...owned.map((p) => p.id), ...links.map((l) => l.patientId)])];
  }

  async update(patientId: string, requestUserId: string, dto: UpdatePatientDto): Promise<Patient> {
    const patient = await this.findOne(patientId, requestUserId);
    Object.assign(patient, dto);
    return this.patients.save(patient);
  }

  private async assertAccess(patient: Patient, requestUserId: string) {
    if (patient.ownerUserId === requestUserId) return;
    const link = await this.links.findOne({
      where: { patientId: patient.id, userId: requestUserId, status: PatientLinkStatus.ACTIVE },
    });
    if (!link) throw new ForbiddenException('No access to this patient');
  }
}
