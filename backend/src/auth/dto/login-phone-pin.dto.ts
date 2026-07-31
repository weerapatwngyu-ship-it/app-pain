import { IsString, Matches } from 'class-validator';

export class LoginPhonePinDto {
  @IsString()
  @Matches(/^0\d{9}$/)
  phone: string;

  @IsString()
  @Matches(/^\d{6}$/)
  pin: string;
}
