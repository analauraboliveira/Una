import { Injectable, BadRequestException } from '@nestjs/common';
import { SupabaseService } from '../supabase/supabase.service';

@Injectable()
export class WithdrawalsService {
  constructor(private supabase: SupabaseService) {}

  async withdraw(userId: string, pointId: string, quantity: number) {
    // 1. A Stored Procedure do banco (register_withdrawal) cuida de:
    // Evitar estoque negativo, acessos simultâneos e auditar na tabela transactions.
    const { data: txId, error: rpcError } = await this.supabase.getClient().rpc('register_withdrawal', {
      p_user_id: userId,
      p_point_id: pointId,
      p_quantity: quantity,
    });

    if (rpcError) {
      // Bloqueia com o motivo retornado do banco (ex: "Insufficient stock")
      throw new BadRequestException(rpcError.message);
    }

    // 2. Critério: Retornar o estoque atualizado do ponto
    const { data: inventoryData } = await this.supabase.getClient()
      .from('inventory')
      .select('quantity, item_type')
      .eq('point_id', pointId);

    return {
      message: 'Retirada efetuada com sucesso!',
      transaction_id: txId,
      updated_inventory: inventoryData
    };
  }
}