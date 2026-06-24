import { IsUUID, IsIn, IsInt, Min } from 'class-validator';

export class CreateDonationDto {
  @IsUUID(undefined, { message: 'point_id deve ser um UUID válido' })
  point_id: string;

  @IsIn(['pad', 'tampon', 'panty_liner'], {
    message: 'item_type deve ser: pad, tampon ou panty_liner',
  })
  item_type: string;

  @IsInt({ message: 'quantity deve ser um número inteiro' })
  @Min(1, { message: 'quantity deve ser maior que zero' })
  quantity: number;
}
