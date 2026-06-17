// B02 - Endpoints de perfil

import { Controller, Post, Body, UseGuards, Request } from '@nestjs/common';
import { ProfilesService } from './profiles.service';
import { CreateProfileDto } from './dto/create-profile.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';

@Controller('profiles')
@UseGuards(JwtAuthGuard)
export class ProfilesController {
  constructor(private profilesService: ProfilesService) {}

  @Post()
  async createProfile(@Request() req, @Body() body: CreateProfileDto) {
    // Garante edição apenas do PRÓPRIO perfil
    return this.profilesService.upsertProfile(req.user.id, body);
  }
}