import { BadRequestException } from '@nestjs/common';
import { existsSync, mkdirSync } from 'fs';
import { diskStorage } from 'multer';
import { extname, join } from 'path';
import { v4 as uuidv4 } from 'uuid';

const ALLOWED_MIME_TYPES: Record<string, string> = {
  'image/jpeg': '.jpg',
  'image/png': '.png',
  'image/webp': '.webp',
};

/** Multer options for an image upload endpoint storing files under
 * `uploads/<subdir>/`, served back at `/uploads/<subdir>/<file>` (see
 * `app.useStaticAssets` in main.ts). Shared by avatar and doctor-photo
 * uploads. */
export function createImageUploadOptions(subdir: string) {
  const dir = join(process.cwd(), 'uploads', subdir);
  if (!existsSync(dir)) mkdirSync(dir, { recursive: true });

  return {
    storage: diskStorage({
      destination: dir,
      filename: (_req, file, callback) => {
        const ext = ALLOWED_MIME_TYPES[file.mimetype] ?? extname(file.originalname);
        callback(null, `${uuidv4()}${ext}`);
      },
    }),
    limits: { fileSize: 5 * 1024 * 1024 },
    fileFilter: (
      _req: unknown,
      file: Express.Multer.File,
      callback: (error: Error | null, accept: boolean) => void,
    ) => {
      if (!ALLOWED_MIME_TYPES[file.mimetype]) {
        callback(new BadRequestException('รองรับเฉพาะไฟล์รูปภาพ JPG, PNG หรือ WEBP เท่านั้น'), false);
        return;
      }
      callback(null, true);
    },
  };
}
