import { IsEnum, IsUUID } from 'class-validator';
import { PatientLinkRole } from '../entities/patient-link.entity';

export class CreatePatientLinkDto {
  @IsUUID()
  patientId: string;

  @IsUUID()
  userId: string;

  @IsEnum(PatientLinkRole)
  role: PatientLinkRole;
}
