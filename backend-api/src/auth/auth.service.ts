// Lógica de Auth

import { Injectable, UnauthorizedException, BadRequestException } from '@nestjs/common';
import { SupabaseService } from '../supabase/supabase.service';

@Injectable()
export class AuthService {
  constructor(private supabase: SupabaseService) {}

  async signUp(email: string, pass: string, metaData: any) {
    // metaData enviará full_name e username para o trigger handle_new_user do BD
    const { data, error } = await this.supabase.getClient().auth.signUp({
      email,
      password: pass,
      options: { data: metaData }
    });
    if (error) throw new BadRequestException(error.message);
    return data;
  }

  async signIn(email: string, pass: string) {
    const { data, error } = await this.supabase.getClient().auth.signInWithPassword({
      email,
      password: pass,
    });
    if (error) throw new UnauthorizedException('Credenciais inválidas');
    return data; // Retorna o session com o JWT (access_token)
  }
}