import { Type } from 'class-transformer';
import {
  ArrayMinSize,
  IsBoolean,
  IsDateString,
  IsOptional,
  IsString,
  IsUUID,
  Matches,
  ValidateNested,
} from 'class-validator';

export class DoseScheduleTimeDto {
  @Matches(/^\d{2}:\d{2}(:\d{2})?$/, { message: 'scheduledTime must be HH:mm or HH:mm:ss' })
  scheduledTime: string;

  @IsOptional()
  @IsBoolean()
  isPrn?: boolean;
}

export class CreatePrescriptionDto {
  @IsUUID()
  patientId: string;

  @IsString()
  medicationName: string;

  @IsString()
  dosage: string;

  @IsString()
  frequency: string;

  @IsDateString()
  startDate: string;

  @IsOptional()
  @IsDateString()
  endDate?: string;

  @ArrayMinSize(1)
  @ValidateNested({ each: true })
  @Type(() => DoseScheduleTimeDto)
  schedule: DoseScheduleTimeDto[];
}
