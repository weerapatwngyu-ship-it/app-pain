import { IsInt, IsObject, IsOptional, IsUUID, Max, Min } from 'class-validator';

export class CreateSymptomLogDto {
  @IsUUID()
  patientId: string;

  @IsInt()
  @Min(0)
  @Max(10)
  painScore: number;

  @IsOptional()
  @IsObject()
  customFields?: Record<string, unknown>;
}
