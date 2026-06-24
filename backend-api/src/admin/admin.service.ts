import {
  Injectable,
  BadRequestException,
  NotFoundException,
} from '@nestjs/common';
import { SupabaseService } from '../supabase/supabase.service';
import { UpdatePointStatusDto } from './dto/update-point-status.dto';
import { UpdateFeedbackStatusDto } from './dto/update-feedback-status.dto';

@Injectable()
export class AdminService {
  constructor(private supabase: SupabaseService) {}

  async listFeedbacks(statusFilter?: string) {
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
      throw new BadRequestException('Erro ao listar feedbacks: ' + error.message);
    }

    return data;
  }

  async updateFeedbackStatus(
    feedbackId: string,
    dto: UpdateFeedbackStatusDto,
    adminId: string,
  ) {
    const client = this.supabase.getClient();

    const { data: existing, error: findError } = await client
      .from('feedbacks')
      .select('id, status')
      .eq('id', feedbackId)
      .single();

    if (findError || !existing) {
      throw new NotFoundException('Feedback não encontrado');
    }

    const updateData: Record<string, any> = { status: dto.status };

    if (dto.status === 'resolved') {
      updateData.resolved_by = adminId;
      updateData.resolved_at = new Date().toISOString();
    } else {
      updateData.resolved_by = null;
      updateData.resolved_at = null;
    }

    const { data: updated, error: updateError } = await client
      .from('feedbacks')
      .update(updateData)
      .eq('id', feedbackId)
      .select('id, status, resolved_by, resolved_at, updated_at')
      .single();

    if (updateError) {
      throw new BadRequestException('Erro ao atualizar feedback: ' + updateError.message);
    }

    return {
      message: `Status do feedback atualizado para "${dto.status}"`,
      feedback: updated,
    };
  }

  async listPoints() {
    const { data, error } = await this.supabase.getClient()
      .from('collection_points')
      .select('id, name, building, campus, floor, room, status, created_at, updated_at, inventory(item_type, quantity, min_quantity)')
      .order('name', { ascending: true });

    if (error) {
      throw new BadRequestException('Erro ao listar pontos: ' + error.message);
    }

    return data;
  }

  async updatePointStatus(pointId: string, dto: UpdatePointStatusDto) {
    const client = this.supabase.getClient();

    const { data: existing, error: findError } = await client
      .from('collection_points')
      .select('id, name')
      .eq('id', pointId)
      .single();

    if (findError || !existing) {
      throw new NotFoundException('Ponto de coleta não encontrado');
    }

    const { data: updated, error: updateError } = await client
      .from('collection_points')
      .update({ status: dto.status })
      .eq('id', pointId)
      .select('id, name, status, updated_at')
      .single();

    if (updateError) {
      throw new BadRequestException('Erro ao atualizar ponto: ' + updateError.message);
    }

    return {
      message: `Status do ponto "${existing.name}" atualizado para "${dto.status}"`,
      point: updated,
    };
  }
}
