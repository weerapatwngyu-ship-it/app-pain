import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AdminModule } from './admin/admin.module';
import { AlertsModule } from './alerts/alerts.module';
import { AuthModule } from './auth/auth.module';
import { DoseLogsModule } from './dose-logs/dose-logs.module';
import { PatientLinksModule } from './patient-links/patient-links.module';
import { PatientsModule } from './patients/patients.module';
import { PrescriptionsModule } from './prescriptions/prescriptions.module';
import { SymptomLogsModule } from './symptom-logs/symptom-logs.module';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    TypeOrmModule.forRootAsync({
      imports: [ConfigModule],
      inject: [ConfigService],
      useFactory: (config: ConfigService) => ({
        type: 'postgres',
        host: config.get<string>('DB_HOST', 'localhost'),
        port: config.get<number>('DB_PORT', 5432),
        username: config.get<string>('DB_USERNAME', 'medtrack'),
        password: config.get<string>('DB_PASSWORD', 'medtrack'),
        database: config.get<string>('DB_NAME', 'medtrack'),
        autoLoadEntities: true,
        synchronize: true,
      }),
    }),
    AuthModule,
    AdminModule,
    PatientsModule,
    PatientLinksModule,
    PrescriptionsModule,
    DoseLogsModule,
    SymptomLogsModule,
    AlertsModule,
  ],
})
export class AppModule {}
