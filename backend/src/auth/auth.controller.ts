import { Body, Controller, Patch, Post, UseGuards } from '@nestjs/common';
import { AuthUser, CurrentUser } from '../common/current-user.decorator';
import { AuthService } from './auth.service';
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
}
