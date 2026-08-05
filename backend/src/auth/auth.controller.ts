import {
  BadRequestException,
  Body,
  Controller,
  Get,
  Patch,
  Post,
  UploadedFile,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { AuthUser, CurrentUser } from '../common/current-user.decorator';
import { imageUploadOptions } from '../common/image-upload.config';
import { ImagesService } from '../images/images.service';
import { AuthService } from './auth.service';
import { JwtAuthGuard } from './jwt-auth.guard';
import { UpdateProfileDto } from './dto/update-profile.dto';

/// Sign-in and sign-up are handled by Supabase Auth in the client, so this
/// controller no longer issues credentials — it only exposes the app-side
/// profile that hangs off the verified Supabase identity.
@UseGuards(JwtAuthGuard)
@Controller('auth')
export class AuthController {
  constructor(
    private readonly authService: AuthService,
    private readonly imagesService: ImagesService,
  ) {}

  /** Called right after Supabase sign-in: the guard has already resolved
   * (and, on first sign-in, created) the local user for this identity. */
  @Get('me')
  me(@CurrentUser() user: AuthUser) {
    return this.authService.currentUser(user.userId);
  }

  @Patch('profile')
  updateProfile(@CurrentUser() user: AuthUser, @Body() dto: UpdateProfileDto) {
    return this.authService.updateProfile(user.userId, dto);
  }

  @Post('avatar')
  @UseInterceptors(FileInterceptor('file', imageUploadOptions))
  async uploadAvatar(@CurrentUser() user: AuthUser, @UploadedFile() file?: Express.Multer.File) {
    if (!file) throw new BadRequestException('กรุณาแนบไฟล์รูปภาพ');
    const url = await this.imagesService.store(file);
    return this.authService.updateAvatar(user.userId, url);
  }
}
