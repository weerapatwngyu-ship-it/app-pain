import { BadRequestException } from '@nestjs/common';
import { diskStorage } from 'multer';
import { existsSync, mkdirSync } from 'fs';
import { extname, join } from 'path';
import { v4 as uuidv4 } from 'uuid';

export const AVATAR_UPLOAD_DIR = join(process.cwd(), 'uploads', 'avatars');

const ALLOWED_MIME_TYPES: Record<string, string> = {
  'image/jpeg': '.jpg',
  'image/png': '.png',
  'image/webp': '.webp',
};

if (!existsSync(AVATAR_UPLOAD_DIR)) {
  mkdirSync(AVATAR_UPLOAD_DIR, { recursive: true });
}

export const avatarUploadOptions = {
  storage: diskStorage({
    destination: AVATAR_UPLOAD_DIR,
    filename: (_req, file, callback) => {
      const ext = ALLOWED_MIME_TYPES[file.mimetype] ?? extname(file.originalname);
      callback(null, `${uuidv4()}${ext}`);
    },
  }),
  limits: { fileSize: 5 * 1024 * 1024 },
  fileFilter: (_req: unknown, file: Express.Multer.File, callback: (error: Error | null, accept: boolean) => void) => {
    if (!ALLOWED_MIME_TYPES[file.mimetype]) {
      callback(new BadRequestException('รองรับเฉพาะไฟล์รูปภาพ JPG, PNG หรือ WEBP เท่านั้น'), false);
      return;
    }
    callback(null, true);
  },
};
