import { Module } from '@nestjs/common';
import { PassportModule } from '@nestjs/passport';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ImagesModule } from '../images/images.module';
import { Patient } from '../patients/entities/patient.entity';
import { AuthController } from './auth.controller';
import { AuthService } from './auth.service';
import { User } from './entities/user.entity';
import { SupabaseJwtStrategy } from './supabase-jwt.strategy';

@Module({
  imports: [TypeOrmModule.forFeature([User, Patient]), ImagesModule, PassportModule],
  controllers: [AuthController],
  providers: [AuthService, SupabaseJwtStrategy],
  exports: [AuthService],
})
export class AuthModule {}
