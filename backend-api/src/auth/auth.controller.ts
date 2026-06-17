// B01 - Rotas de Login/Cadastro

import { Body, Controller, Post } from '@nestjs/common';
import { AuthService } from './auth.service';

@Controller('auth')
export class AuthController {
  constructor(private authService: AuthService) {}

  @Post('register')
  async register(@Body() body: any) {
    // Espera email, password, full_name, username
    return this.authService.signUp(body.email, body.password, {
      full_name: body.full_name,
      username: body.username,
      pronouns: body.pronouns
    });
  }

  @Post('login')
  async login(@Body() body: any) {
    return this.authService.signIn(body.email, body.password);
  }
}