import { Injectable, BadRequestException, NotFoundException } from '@nestjs/common';
import { SupabaseService } from '../supabase/supabase.service';
import { CreateDonationDto } from './dto/create-donation.dto';

@Injectable()
export class DonationsService {
  constructor(private supabase: SupabaseService) {}

  async donate(userId: string, dto: CreateDonationDto) {
    const client = this.supabase.getClient();

    const { data: point, error: pointError } = await client
      .from('collection_points')
      .select('id, name, status')
      .eq('id', dto.point_id)
      .single();

    if (pointError || !point) {
      throw new NotFoundException('Ponto de coleta não encontrado');
    }

    if (point.status !== 'active') {
      throw new BadRequestException(
        `O ponto "${point.name}" não está ativo (status: ${point.status}). Doações só são aceitas em pontos ativos.`,
      );
    }

    const { data: inventory } = await client
      .from('inventory')
      .select('id')
      .eq('point_id', dto.point_id)
      .eq('item_type', dto.item_type)
      .single();

    if (!inventory) {
      throw new BadRequestException(
        `Não há registro de estoque para "${dto.item_type}" neste ponto. Contate uma administradora.`,
      );
    }

    const { data: transaction, error: txError } = await client
      .from('transactions')
      .insert({
        type: 'donation',
        user_id: userId,
        point_id: dto.point_id,
        item_type: dto.item_type,
        quantity: dto.quantity,
      })
      .select('id, created_at')
      .single();

    if (txError) {
      throw new BadRequestException('Erro ao registrar doação: ' + txError.message);
    }

    const { data: updatedInventory } = await client
      .from('inventory')
      .select('item_type, quantity')
      .eq('point_id', dto.point_id);

    return {
      message: 'Doação registrada com sucesso!',
      transaction_id: transaction.id,
      created_at: transaction.created_at,
      updated_inventory: updatedInventory,
    };
  }
}
