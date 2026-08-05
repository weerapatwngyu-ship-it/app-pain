import 'reflect-metadata';
import { NestFactory } from '@nestjs/core';
import { NestExpressApplication } from '@nestjs/platform-express';
import { ValidationPipe } from '@nestjs/common';
import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create<NestExpressApplication>(AppModule);

  // Hosted platforms (Render et al) put a proxy in front of the app, so the
  // socket address is the proxy's. Without this the rate limiter buckets
  // every user together under one IP and one caller can lock out the rest.
  app.set('trust proxy', 1);

  // Native mobile clients don't send an Origin, so CORS is only about
  // browser callers. Allow the ones listed in CORS_ORIGINS (comma
  // separated); with none set, no browser origin is granted access.
  const corsOrigins = (process.env.CORS_ORIGINS ?? '')
    .split(',')
    .map((origin) => origin.trim())
    .filter(Boolean);
  app.enableCors({ origin: corsOrigins.length > 0 ? corsOrigins : false });

  app.setGlobalPrefix('v1');
  app.useGlobalPipes(
    new ValidationPipe({ whitelist: true, transform: true, forbidNonWhitelisted: true }),
  );
  const port = process.env.PORT ?? 3000;
  await app.listen(port, '0.0.0.0');
}
bootstrap();
