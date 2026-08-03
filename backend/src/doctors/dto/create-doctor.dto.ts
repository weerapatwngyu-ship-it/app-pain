import { IsNotEmpty, IsOptional, IsString, MaxLength } from 'class-validator';

export class CreateDoctorDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(120)
  name: string;

  @IsString()
  @IsNotEmpty()
  @MaxLength(120)
  specialty: string;

  @IsOptional()
  @IsString()
  @MaxLength(2000)
  bio?: string;
}
