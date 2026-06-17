// Proteção de rotas com JWT

import { Injectable, CanActivate, ExecutionContext, UnauthorizedException } from '@nestjs/common';
import { SupabaseService } from '../../supabase/supabase.service';

@Injectable()
export class JwtAuthGuard implements CanActivate {
  constructor(private supabase: SupabaseService) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest();
    const token = this.extractTokenFromHeader(request);
    
    if (!token) throw new UnauthorizedException('Token não fornecido');

    // Valida o token no Supabase
    const { data: { user }, error } = await this.supabase.getClient().auth.getUser(token);
    if (error || !user) throw new UnauthorizedException('Token inválido ou expirado');

    // Pega o papel (role) atualizado do banco de dados (Task B01: diferenciar comum/admin)
    const { data: profile } = await this.supabase.getClient()
      .from('profiles')
      .select('role')
      .eq('id', user.id)
      .single();

    // Injeta o usuário na requisição
    request.user = { 
      id: user.id, 
      email: user.email, 
      role: profile?.role || 'student' // 'student' é a role padrão segundo .sql
    };

    return true;
  }

  private extractTokenFromHeader(request: any): string | undefined {
    const [type, token] = request.headers.authorization?.split(' ') ?? [];
    return type === 'Bearer' ? token : undefined;
  }
}