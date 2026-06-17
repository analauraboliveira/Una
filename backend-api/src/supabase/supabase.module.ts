import { Global, Module } from '@nestjs/common';
import { SupabaseService } from './supabase.service';

@Global() // Torna o Supabase acessível em toda a aplicação sem precisar importar o módulo toda hora
@Module({
  providers: [SupabaseService],
  exports: [SupabaseService],
})
export class SupabaseModule {}