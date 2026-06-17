import { Controller, Post, Get, Body, UseGuards, Request } from '@nestjs/common';
import { FeedbacksService } from './feedbacks.service';
import { CreateFeedbackDto } from './dto/create-feedback.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';

@Controller('feedbacks')
@UseGuards(JwtAuthGuard)
export class FeedbacksController {
  constructor(private feedbacksService: FeedbacksService) {}

  @Post()
  async create(@Request() req, @Body() body: CreateFeedbackDto) {
    return this.feedbacksService.create(req.user.id, body);
  }

  @Get('me')
  async findMine(@Request() req) {
    return this.feedbacksService.findByUser(req.user.id);
  }
}
