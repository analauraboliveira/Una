import { Injectable, BadRequestException, NotFoundException } from '@nestjs/common';
import { SupabaseService } from '../supabase/supabase.service';
import { CreateFeedbackDto } from './dto/create-feedback.dto';

@Injectable()
export class FeedbacksService {
  constructor(private supabase: SupabaseService) {}

  async create(userId: string, dto: CreateFeedbackDto) {
    const client = this.supabase.getClient();

    const { data: point, error: pointError } = await client
      .from('collection_points')
      .select('id, name')
      .eq('id', dto.point_id)
      .single();

    if (pointError || !point) {
      throw new NotFoundException('Ponto de coleta não encontrado');
    }

    if (dto.is_specific && (!dto.description || dto.description.trim().length === 0)) {
      throw new BadRequestException(
        'Descrição é obrigatória para problemas específicos (is_specific = true)',
      );
    }

    const { data: feedback, error: insertError } = await client
      .from('feedbacks')
      .insert({
        point_id: dto.point_id,
        submitted_by: userId,
        category: dto.category,
        is_specific: dto.is_specific,
        description: dto.description || null,
        status: 'pending',
      })
      .select('id, category, is_specific, description, status, created_at')
      .single();

    if (insertError) {
      throw new BadRequestException('Erro ao registrar feedback: ' + insertError.message);
    }

    return {
      message: 'Feedback registrado com sucesso!',
      feedback,
    };
  }

  async findByUser(userId: string) {
    const { data, error } = await this.supabase.getClient()
      .from('feedbacks')
      .select(`
        id, category, is_specific, description, status,
        created_at, updated_at,
        collection_points(id, name, building)
      `)
      .eq('submitted_by', userId)
      .order('created_at', { ascending: false });

    if (error) {
      throw new BadRequestException('Erro ao buscar feedbacks: ' + error.message);
    }

    return data;
  }

  async findAll(statusFilter?: string) {
    let query = this.supabase.getClient()
      .from('feedbacks')
      .select(`
        id, category, is_specific, description, status,
        created_at, updated_at, resolved_at,
        submitted_by, resolved_by,
        collection_points(id, name, building),
        profiles!feedbacks_submitted_by_fkey(full_name, username)
      `)
      .order('created_at', { ascending: false });

    if (statusFilter) {
      query = query.eq('status', statusFilter);
    }

    const { data, error } = await query;

    if (error) {
      throw new BadRequestException('Erro ao buscar feedbacks: ' + error.message);
    }

    return data;
  }
}
