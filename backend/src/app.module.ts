import { Module } from '@nestjs/common';
import { APP_GUARD } from '@nestjs/core';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { ThrottlerGuard, ThrottlerModule } from '@nestjs/throttler';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AdminModule } from './admin/admin.module';
import { AlertsModule } from './alerts/alerts.module';
import { AuthModule } from './auth/auth.module';
import { DoctorsModule } from './doctors/doctors.module';
import { DoseLogsModule } from './dose-logs/dose-logs.module';
import { ImagesModule } from './images/images.module';
import { PatientLinksModule } from './patient-links/patient-links.module';
import { PatientsModule } from './patients/patients.module';
import { PharmaciesModule } from './pharmacies/pharmacies.module';
import { PrescriptionsModule } from './prescriptions/prescriptions.module';
import { SymptomLogsModule } from './symptom-logs/symptom-logs.module';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    // Baseline request cap per IP. Auth endpoints tighten this further —
    // without a cap, OTP requests and PIN guesses can be run in bulk.
    ThrottlerModule.forRoot([{ ttl: 60_000, limit: 100 }]),
    TypeOrmModule.forRootAsync({
      imports: [ConfigModule],
      inject: [ConfigService],
      useFactory: (config: ConfigService) => {
        // Hosted Postgres (Render/Neon/Supabase/etc) is normally handed to
        // you as one connection string via DATABASE_URL, and needs SSL.
        // Local dev keeps using the discrete DB_* vars from .env.
        const databaseUrl = config.get<string>('DATABASE_URL');
        return {
          type: 'postgres',
          ...(databaseUrl
            ? { url: databaseUrl, ssl: { rejectUnauthorized: false } }
            : {
                host: config.get<string>('DB_HOST', 'localhost'),
                port: config.get<number>('DB_PORT', 5432),
                username: config.get<string>('DB_USERNAME', 'medtrack'),
                password: config.get<string>('DB_PASSWORD', 'medtrack'),
                database: config.get<string>('DB_NAME', 'medtrack'),
              }),
          autoLoadEntities: true,
          synchronize: true,
        };
      },
    }),
    AuthModule,
    AdminModule,
    PatientsModule,
    PatientLinksModule,
    PrescriptionsModule,
    DoseLogsModule,
    SymptomLogsModule,
    AlertsModule,
    PharmaciesModule,
    DoctorsModule,
    ImagesModule,
  ],
  providers: [{ provide: APP_GUARD, useClass: ThrottlerGuard }],
})
export class AppModule {}
