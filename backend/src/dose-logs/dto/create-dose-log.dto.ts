import { IsEnum, IsISO8601, IsOptional, IsUUID } from 'class-validator';
import { DoseLogStatus } from '../entities/dose-log.entity';

export class CreateDoseLogDto {
  @IsUUID()
  scheduleId: string;

  @IsISO8601()
  scheduledAt: string;

  @IsOptional()
  @IsISO8601()
  actionedAt?: string;

  @IsEnum(DoseLogStatus)
  status: DoseLogStatus;
}
