import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { APP_FILTER, APP_PIPE } from '@nestjs/core';
import { SupabaseModule } from './supabase/supabase.module';
import { AuthModule } from './auth/auth.module';
import { ProfilesModule } from './profiles/profiles.module';
import { PointsModule } from './points/points.module';
import { WithdrawalsModule } from './withdrawals/withdrawals.module';
import { DonationsModule } from './donations/donations.module';
import { FeedbacksModule } from './feedbacks/feedbacks.module';
import { AdminModule } from './admin/admin.module';
import { AllExceptionsFilter } from './common/filters/all-exceptions.filter';
import { createValidationPipe } from './common/pipes/validation.pipe';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    SupabaseModule,
    AuthModule,
    ProfilesModule,
    PointsModule,
    WithdrawalsModule,
    DonationsModule,
    FeedbacksModule,
    AdminModule,
  ],
  providers: [
    {
      provide: APP_FILTER,
      useClass: AllExceptionsFilter,
    },
    {
      provide: APP_PIPE,
      useValue: createValidationPipe(),
    },
  ],
})
export class AppModule {}
