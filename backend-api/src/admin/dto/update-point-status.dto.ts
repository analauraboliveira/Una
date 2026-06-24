import { IsIn, IsOptional } from 'class-validator';

export class UpdatePointStatusDto {
  @IsIn(['active', 'inactive', 'maintenance'], {
    message: 'status deve ser: active, inactive ou maintenance',
  })
  status: string;
}
