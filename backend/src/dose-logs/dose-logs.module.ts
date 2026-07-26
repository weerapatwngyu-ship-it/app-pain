import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { DoseLogsController } from './dose-logs.controller';
import { DoseLogsService } from './dose-logs.service';
import { DoseLog } from './entities/dose-log.entity';

@Module({
  imports: [TypeOrmModule.forFeature([DoseLog])],
  controllers: [DoseLogsController],
  providers: [DoseLogsService],
  exports: [TypeOrmModule, DoseLogsService],
})
export class DoseLogsModule {}
