import { IsString, Matches } from 'class-validator';

export class OtpVerifyDto {
  @IsString()
  @Matches(/^0\d{9}$/)
  phone: string;

  @IsString()
  @Matches(/^\d{6}$/, { message: 'รหัส OTP ต้องเป็นตัวเลข 6 หลัก' })
  otp: string;
}
