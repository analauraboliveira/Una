import { Injectable, BadRequestException } from '@nestjs/common';
import { SupabaseService } from '../supabase/supabase.service';
import { CreateProfileDto } from './dto/create-profile.dto';

@Injectable()
export class ProfilesService {
  constructor(private supabase: SupabaseService) {}

  async upsertProfile(userId: string, data: CreateProfileDto) {
    // Upsert para atualizar ou preencher o perfil
    const { data: profile, error } = await this.supabase.getClient()
      .from('profiles')
      .update(data)
      .eq('id', userId)
      .select()
      .single();

    if (error) throw new BadRequestException('Erro ao salvar perfil: ' + error.message);
    return profile;
  }
}