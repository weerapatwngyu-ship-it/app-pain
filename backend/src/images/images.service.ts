import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { UploadedImage } from './entities/uploaded-image.entity';

@Injectable()
export class ImagesService {
  constructor(
    @InjectRepository(UploadedImage) private readonly images: Repository<UploadedImage>,
  ) {}

  /** Stores the image and returns the API path to read it back, which is
   * what callers persist on the owning record (user.avatarUrl etc). */
  async store(file: Express.Multer.File): Promise<string> {
    const saved = await this.images.save(
      this.images.create({ mimeType: file.mimetype, data: file.buffer }),
    );
    return `/images/${saved.id}`;
  }

  async findOne(id: string): Promise<UploadedImage> {
    const image = await this.images.findOne({ where: { id } });
    if (!image) throw new NotFoundException('ไม่พบรูปภาพ');
    return image;
  }
}
