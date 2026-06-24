import {
  Controller,
  Get,
  Patch,
  Param,
  Query,
  Body,
  UseGuards,
  Request,
} from '@nestjs/common';
import { AdminService } from './admin.service';
import { UpdatePointStatusDto } from './dto/update-point-status.dto';
import { UpdateFeedbackStatusDto } from './dto/update-feedback-status.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { AdminGuard } from '../auth/guards/admin.guard';

@Controller('admin')
@UseGuards(JwtAuthGuard, AdminGuard)
export class AdminController {
  constructor(private adminService: AdminService) {}

  @Get('feedbacks')
  async listFeedbacks(@Query('status') status?: string) {
    return this.adminService.listFeedbacks(status);
  }

  @Patch('feedbacks/:id/status')
  async updateFeedbackStatus(
    @Param('id') id: string,
    @Body() body: UpdateFeedbackStatusDto,
    @Request() req,
  ) {
    return this.adminService.updateFeedbackStatus(id, body, req.user.id);
  }

  @Get('points')
  async listPoints() {
    return this.adminService.listPoints();
  }

  @Patch('points/:id')
  async updatePointStatus(
    @Param('id') id: string,
    @Body() body: UpdatePointStatusDto,
  ) {
    return this.adminService.updatePointStatus(id, body);
  }
}
