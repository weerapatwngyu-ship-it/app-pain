import {
  BadRequestException,
  Body,
  Controller,
  Get,
  Param,
  Patch,
  Post,
  UploadedFile,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { UserRole } from '../auth/entities/user.entity';
import { imageUploadOptions } from '../common/image-upload.config';
import { Roles } from '../common/roles.decorator';
import { RolesGuard } from '../common/roles.guard';
import { ImagesService } from '../images/images.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CreateDoctorDto } from './dto/create-doctor.dto';
import { UpdateDoctorDto } from './dto/update-doctor.dto';
import { DoctorsService } from './doctors.service';

// Reading the directory is open to any signed-in user; creating or editing a
// doctor profile is staff-only, so one patient can't rewrite the entry every
// other patient sees.
@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('doctors')
export class DoctorsController {
  constructor(
    private readonly doctorsService: DoctorsService,
    private readonly imagesService: ImagesService,
  ) {}

  @Post()
  @Roles(UserRole.PROVIDER, UserRole.ADMIN)
  create(@Body() dto: CreateDoctorDto) {
    return this.doctorsService.create(dto);
  }

  @Get()
  findAll() {
    return this.doctorsService.findAll();
  }

  @Get(':id')
  findOne(@Param('id') id: string) {
    return this.doctorsService.findOne(id);
  }

  @Patch(':id')
  @Roles(UserRole.PROVIDER, UserRole.ADMIN)
  update(@Param('id') id: string, @Body() dto: UpdateDoctorDto) {
    return this.doctorsService.update(id, dto);
  }

  @Post(':id/photo')
  @Roles(UserRole.PROVIDER, UserRole.ADMIN)
  @UseInterceptors(FileInterceptor('file', imageUploadOptions))
  async uploadPhoto(@Param('id') id: string, @UploadedFile() file?: Express.Multer.File) {
    if (!file) throw new BadRequestException('กรุณาแนบไฟล์รูปภาพ');
    const url = await this.imagesService.store(file);
    return this.doctorsService.updatePhoto(id, url);
  }
}
