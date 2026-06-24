import { Module } from '@nestjs/common';
import { FeedbacksService } from './feedbacks.service';
import { FeedbacksController } from './feedbacks.controller';

@Module({
  providers: [FeedbacksService],
  controllers: [FeedbacksController],
  exports: [FeedbacksService],
})
export class FeedbacksModule {}
