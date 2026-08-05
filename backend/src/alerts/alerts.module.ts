import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { PatientsModule } from '../patients/patients.module';
import { AlertsController } from './alerts.controller';
import { AlertsService } from './alerts.service';
import { AlertRule } from './entities/alert-rule.entity';
import { Alert } from './entities/alert.entity';

@Module({
  imports: [TypeOrmModule.forFeature([Alert, AlertRule]), PatientsModule],
  controllers: [AlertsController],
  providers: [AlertsService],
  exports: [TypeOrmModule],
})
export class AlertsModule {}
