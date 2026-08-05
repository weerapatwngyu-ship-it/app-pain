import { Controller, Get, Header, Param, Res } from '@nestjs/common';
import type { Response } from 'express';
import { ImagesService } from './images.service';

@Controller('images')
export class ImagesController {
  constructor(private readonly imagesService: ImagesService) {}

  /** Unauthenticated on purpose: Flutter's NetworkImage can't attach the
   * bearer token. Ids are random UUIDs, so an image is only reachable by
   * someone already given its URL — the same exposure the previous
   * static-file serving had. */
  @Get(':id')
  @Header('Cache-Control', 'public, max-age=31536000, immutable')
  async findOne(@Param('id') id: string, @Res() res: Response) {
    const image = await this.imagesService.findOne(id);
    res.type(image.mimeType).send(image.data);
  }
}
