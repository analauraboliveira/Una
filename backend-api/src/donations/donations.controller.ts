import { Controller, Post, Body, UseGuards, Request } from '@nestjs/common';
import { DonationsService } from './donations.service';
import { CreateDonationDto } from './dto/create-donation.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';

@Controller('donations')
@UseGuards(JwtAuthGuard)
export class DonationsController {
  constructor(private donationsService: DonationsService) {}

  @Post()
  async createDonation(@Request() req, @Body() body: CreateDonationDto) {
    return this.donationsService.donate(req.user.id, body);
  }
}
