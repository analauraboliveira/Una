import { IsUUID, IsNumber, Min } from 'class-validator';

export class CreateWithdrawalDto {
  @IsUUID() point_id: string;
  @IsNumber() @Min(1) quantity: number;
}