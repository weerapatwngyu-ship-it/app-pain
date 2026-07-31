import { IsString, Matches } from 'class-validator';

export class OtpRequestDto {
  @IsString()
  @Matches(/^0\d{9}$/, { message: 'เบอร์โทรศัพท์ต้องเป็นตัวเลข 10 หลักขึ้นต้นด้วย 0' })
  phone: string;
}
