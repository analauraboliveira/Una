import { Injectable, NotFoundException } from '@nestjs/common';
import { SupabaseService } from '../supabase/supabase.service';

@Injectable()
export class PointsService {
  constructor(private supabase: SupabaseService) {}

  async findAll(userRole: string) {
    // Busca dados compatíveis com o mapa e faz Join com inventory para pegar a quantidade
    let query = this.supabase.getClient()
      .from('collection_points')
      .select('id, name, location, status, inventory(item_type, quantity)');
    
    // Filtro para usuárias comuns: apenas ativos
    if (userRole !== 'admin') {
      query = query.eq('status', 'active'); // Enum: 'active' | 'inactive' | 'maintenance'
    }

    const { data, error } = await query;
    if (error) throw new NotFoundException('Erro ao buscar points');
    return data;
  }

  async findOne(id: string, userRole: string) {
    let query = this.supabase.getClient()
      .from('collection_points')
      .select('*, inventory(item_type, quantity)')
      .eq('id', id);
    
    if (userRole !== 'admin') {
      query = query.eq('status', 'active');
    }

    const { data, error } = await query.single();
    if (error || !data) throw new NotFoundException('Point inativo ou não encontrado');
    return data;
  }
}