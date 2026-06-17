// B04 - Regras de Retirada

import { Controller, Post, Body, UseGuards, Request } from '@nestjs/common';
import { WithdrawalsService } from './withdrawals.service';
import { CreateWithdrawalDto } from './dto/create-withdrawal.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';

@Controller('withdrawals')
@UseGuards(JwtAuthGuard)
export class WithdrawalsController {
  constructor(private withdrawalsService: WithdrawalsService) {}

  @Post()
  async createWithdrawal(@Request() req, @Body() body: CreateWithdrawalDto) {
    return this.withdrawalsService.withdraw(req.user.id, body.point_id, body.quantity);
  }
}