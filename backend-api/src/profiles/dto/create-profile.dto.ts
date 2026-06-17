// Validação

import { IsNumber, IsOptional, IsString } from 'class-validator';

export class CreateProfileDto {
  @IsOptional() @IsString() full_name?: string;
  @IsOptional() @IsString() pronouns?: string;
  @IsOptional() @IsNumber() age?: number;
  @IsOptional() @IsNumber() cycle_duration_days?: number;
}