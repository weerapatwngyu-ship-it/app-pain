import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AlertsController } from './alerts.controller';
import { AlertsService } from './alerts.service';
import { AlertRule } from './entities/alert-rule.entity';
import { Alert } from './entities/alert.entity';

@Module({
  imports: [TypeOrmModule.forFeature([Alert, AlertRule])],
  controllers: [AlertsController],
  providers: [AlertsService],
  exports: [TypeOrmModule],
})
export class AlertsModule {}
