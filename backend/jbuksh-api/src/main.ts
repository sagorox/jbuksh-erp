import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { join } from 'path';
import * as express from 'express';
import { ValidationPipe } from '@nestjs/common'; // ✅ ValidationPipe ইমপোর্ট করুন

async function bootstrap() {
  const app = await NestFactory.create(AppModule);

  // ✅ Global Validation Pipe সেট করুন
  // এটি আপনার DTO-তে থাকা @IsString, @IsArray ইত্যাদি রুলসগুলো কার্যকর করবে
  app.useGlobalPipes(new ValidationPipe({
    whitelist: true,
    transform: true,
    forbidNonWhitelisted: true,
  }));

  // ✅ serve /storage as /files
  // এটি করার ফলে আপনার 'storage' ফোল্ডারের ফাইলগুলো '/files' প্রিফিক্স দিয়ে এক্সেস করা যাবে
  app.use('/files', express.static(join(process.cwd(), 'storage')));

  await app.listen(3000);
}
bootstrap();