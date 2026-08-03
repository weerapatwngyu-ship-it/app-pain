import {
  BadRequestException,
  Body,
  Controller,
  Patch,
  Post,
  UploadedFile,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { AuthUser, CurrentUser } from '../common/current-user.decorator';
import { AuthService } from './auth.service';
import { avatarUploadOptions } from './avatar-upload.config';
import { JwtAuthGuard } from './jwt-auth.guard';
import { LoginPhonePinDto } from './dto/login-phone-pin.dto';
import { LoginDto } from './dto/login.dto';
import { OtpRequestDto } from './dto/otp-request.dto';
import { OtpVerifyDto } from './dto/otp-verify.dto';
import { RegisterPhoneDto } from './dto/register-phone.dto';
import { RegisterDto } from './dto/register.dto';
import { UpdateProfileDto } from './dto/update-profile.dto';

@Controller('auth')
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  @Post('register')
  register(@Body() dto: RegisterDto) {
    return this.authService.register(dto);
  }

  @Post('login')
  login(@Body() dto: LoginDto) {
    return this.authService.login(dto);
  }

  @Post('otp/request')
  requestOtp(@Body() dto: OtpRequestDto) {
    return this.authService.requestOtp(dto);
  }

  @Post('otp/verify')
  verifyOtp(@Body() dto: OtpVerifyDto) {
    return this.authService.verifyOtp(dto);
  }

  @Post('register-phone')
  registerWithPhone(@Body() dto: RegisterPhoneDto) {
    return this.authService.registerWithPhone(dto);
  }

  @Post('login-phone-pin')
  loginWithPhonePin(@Body() dto: LoginPhonePinDto) {
    return this.authService.loginWithPhonePin(dto);
  }

  @UseGuards(JwtAuthGuard)
  @Patch('profile')
  updateProfile(@CurrentUser() user: AuthUser, @Body() dto: UpdateProfileDto) {
    return this.authService.updateProfile(user.userId, dto);
  }

  @UseGuards(JwtAuthGuard)
  @Post('avatar')
  @UseInterceptors(FileInterceptor('file', avatarUploadOptions))
  uploadAvatar(@CurrentUser() user: AuthUser, @UploadedFile() file?: Express.Multer.File) {
    if (!file) throw new BadRequestException('กรุณาแนบไฟล์รูปภาพ');
    return this.authService.updateAvatar(user.userId, `/uploads/avatars/${file.filename}`);
  }
}
