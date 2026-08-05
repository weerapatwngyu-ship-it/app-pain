import { BadRequestException } from '@nestjs/common';
import { memoryStorage } from 'multer';

const ALLOWED_MIME_TYPES = ['image/jpeg', 'image/png', 'image/webp'];

/** Multer options for image uploads. Files are held in memory and then
 * written to Postgres by ImagesService — hosted free tiers reset the
 * container filesystem, so anything saved to disk is lost on restart.
 *
 * The 2 MB cap keeps a handful of avatars from eating a free database
 * quota; the mobile client already downscales before uploading. */
export const imageUploadOptions = {
  storage: memoryStorage(),
  limits: { fileSize: 2 * 1024 * 1024 },
  fileFilter: (
    _req: unknown,
    file: Express.Multer.File,
    callback: (error: Error | null, accept: boolean) => void,
  ) => {
    if (!ALLOWED_MIME_TYPES.includes(file.mimetype)) {
      callback(new BadRequestException('รองรับเฉพาะไฟล์รูปภาพ JPG, PNG หรือ WEBP เท่านั้น'), false);
      return;
    }
    callback(null, true);
  },
};
