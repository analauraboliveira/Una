// B03 - Listagem e Detalhes

import { Controller, Get, Param, UseGuards, Request } from '@nestjs/common';
import { PointsService } from './points.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';

@Controller('points')
@UseGuards(JwtAuthGuard)
export class PointsController {
  constructor(private pointsService: PointsService) {}

  @Get()
  findAll(@Request() req) {
    return this.pointsService.findAll(req.user.role);
  }

  @Get(':id')
  findOne(@Param('id') id: string, @Request() req) {
    return this.pointsService.findOne(id, req.user.role);
  }
}