import { IsIn, IsInt, IsObject, IsOptional, IsUUID, Max, Min } from 'class-validator';

export const SYMPTOM_CATEGORIES = [
  'head',
  'stomach',
  'skin',
  'respiratory',
  'joint',
  'other',
] as const;

export class CreateSymptomLogDto {
  @IsUUID()
  patientId: string;

  @IsInt()
  @Min(0)
  @Max(10)
  painScore: number;

  @IsOptional()
  @IsIn(SYMPTOM_CATEGORIES)
  category?: string;

  @IsOptional()
  @IsObject()
  customFields?: Record<string, unknown>;
}
