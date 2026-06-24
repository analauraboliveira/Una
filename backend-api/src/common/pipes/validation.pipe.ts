import { ValidationPipe, BadRequestException, ValidationError } from '@nestjs/common';

export function createValidationPipe(): ValidationPipe {
  return new ValidationPipe({
    whitelist: true,
    forbidNonWhitelisted: true,
    transform: true,
    transformOptions: {
      enableImplicitConversion: true,
    },
    exceptionFactory: (errors: ValidationError[]) => {
      const messages = formatValidationErrors(errors);
      return new BadRequestException({
        statusCode: 400,
        error: 'Erro de Validação',
        message: messages,
      });
    },
  });
}

function formatValidationErrors(errors: ValidationError[], parentField = ''): string[] {
  const messages: string[] = [];

  for (const error of errors) {
    const field = parentField ? `${parentField}.${error.property}` : error.property;

    if (error.constraints) {
      for (const constraint of Object.values(error.constraints)) {
        messages.push(`${field}: ${constraint}`);
      }
    }

    if (error.children && error.children.length > 0) {
      messages.push(...formatValidationErrors(error.children, field));
    }
  }

  return messages;
}
