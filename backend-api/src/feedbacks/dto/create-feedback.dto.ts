import {
  IsUUID,
  IsIn,
  IsBoolean,
  IsString,
  IsNotEmpty,
  IsOptional,
  ValidateIf,
} from 'class-validator';

export class CreateFeedbackDto {
  @IsUUID(undefined, { message: 'point_id deve ser um UUID válido' })
  point_id: string;

  @IsIn(['empty_stock', 'damaged', 'inaccessible', 'other'], {
    message: 'category deve ser: empty_stock, damaged, inaccessible ou other',
  })
  category: string;

  @IsBoolean({ message: 'is_specific deve ser true ou false' })
  is_specific: boolean;

  @ValidateIf((o) => o.is_specific === true)
  @IsString({ message: 'description deve ser uma string' })
  @IsNotEmpty({ message: 'description é obrigatório quando is_specific é true' })
  description?: string;
}
