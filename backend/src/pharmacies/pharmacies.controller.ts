import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { NearbyQueryDto } from './dto/nearby-query.dto';
import { PharmaciesService } from './pharmacies.service';

@UseGuards(JwtAuthGuard)
@Controller('pharmacies')
export class PharmaciesController {
  constructor(private readonly pharmaciesService: PharmaciesService) {}

  @Get('nearby')
  findNearby(@Query() query: NearbyQueryDto) {
    return this.pharmaciesService.findNearby(query);
  }
}
