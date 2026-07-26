import { IsDateString, IsOptional, IsString } from 'class-validator';

export class CreatePatientDto {
  @IsString()
  name: string;

  @IsDateString()
  birthDate: string;

  @IsOptional()
  @IsString()
  primaryCondition?: string;
}
