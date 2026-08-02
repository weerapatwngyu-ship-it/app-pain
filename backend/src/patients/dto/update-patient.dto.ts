import { IsDateString, IsIn, IsOptional, IsString } from 'class-validator';

export class UpdatePatientDto {
  @IsOptional()
  @IsString()
  name?: string;

  @IsOptional()
  @IsDateString()
  birthDate?: string;

  @IsOptional()
  @IsIn(['female', 'male', 'unspecified'])
  gender?: string;
}
