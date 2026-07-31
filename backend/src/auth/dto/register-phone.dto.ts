import { IsBoolean, IsEmail, IsIn, IsOptional, IsString, Matches } from 'class-validator';

export class RegisterPhoneDto {
  @IsString()
  @Matches(/^0\d{9}$/)
  phone: string;

  @IsString()
  @Matches(/^\d{6}$/, { message: 'PIN ต้องเป็นตัวเลข 6 หลัก' })
  pin: string;

  @IsBoolean()
  consentHealth: boolean;

  @IsBoolean()
  consentMarketing: boolean;

  @IsString()
  firstName: string;

  @IsString()
  lastName: string;

  @IsEmail()
  email: string;

  @IsString()
  @Matches(/^\d{4}-\d{2}-\d{2}$/, { message: 'วันเกิดต้องอยู่ในรูปแบบ YYYY-MM-DD' })
  birthDate: string;

  @IsOptional()
  @IsIn(['female', 'male', 'unspecified'])
  gender?: string;
}
