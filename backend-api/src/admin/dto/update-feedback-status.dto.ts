import { IsIn } from 'class-validator';

export class UpdateFeedbackStatusDto {
  @IsIn(['pending', 'in_progress', 'resolved'], {
    message: 'status deve ser: pending, in_progress ou resolved',
  })
  status: string;
}
