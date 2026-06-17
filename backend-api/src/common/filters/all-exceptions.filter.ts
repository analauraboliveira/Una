import {
  ExceptionFilter,
  Catch,
  ArgumentsHost,
  HttpException,
  HttpStatus,
  Logger,
} from '@nestjs/common';
import { Response } from 'express';

interface ErrorResponse {
  statusCode: number;
  error: string;
  message: string | string[];
  timestamp: string;
}

@Catch()
export class AllExceptionsFilter implements ExceptionFilter {
  private readonly logger = new Logger(AllExceptionsFilter.name);

  catch(exception: unknown, host: ArgumentsHost): void {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse<Response>();

    const errorResponse = this.buildErrorResponse(exception);

    if (errorResponse.statusCode >= 500) {
      this.logger.error(
        `[${errorResponse.statusCode}] ${errorResponse.message}`,
        exception instanceof Error ? exception.stack : undefined,
      );
    }

    response.status(errorResponse.statusCode).json(errorResponse);
  }

  private buildErrorResponse(exception: unknown): ErrorResponse {
    if (exception instanceof HttpException) {
      const status = exception.getStatus();
      const exceptionResponse = exception.getResponse();

      const message =
        typeof exceptionResponse === 'object' && exceptionResponse !== null
          ? (exceptionResponse as any).message || exception.message
          : exception.message;

      return {
        statusCode: status,
        error: this.getErrorName(status),
        message,
        timestamp: new Date().toISOString(),
      };
    }

    if (this.isPostgresError(exception)) {
      return this.handlePostgresError(exception);
    }

    return {
      statusCode: HttpStatus.INTERNAL_SERVER_ERROR,
      error: 'Internal Server Error',
      message: 'Erro interno do servidor. Tente novamente mais tarde.',
      timestamp: new Date().toISOString(),
    };
  }

  private isPostgresError(err: unknown): err is { code: string; message: string } {
    return (
      typeof err === 'object' &&
      err !== null &&
      'code' in err &&
      typeof (err as any).code === 'string'
    );
  }

  private handlePostgresError(err: { code: string; message: string }): ErrorResponse {
    const pgErrorMap: Record<string, { status: number; message: string }> = {
      '23505': { status: HttpStatus.CONFLICT, message: 'Registro duplicado. Este dado já existe.' },
      '23503': { status: HttpStatus.BAD_REQUEST, message: 'Referência inválida. O registro relacionado não existe.' },
      '23514': { status: HttpStatus.BAD_REQUEST, message: 'Valor fora do intervalo permitido.' },
      'P0002': { status: HttpStatus.NOT_FOUND, message: 'Registro não encontrado.' },
    };

    const mapped = pgErrorMap[err.code];
    if (mapped) {
      return {
        statusCode: mapped.status,
        error: this.getErrorName(mapped.status),
        message: mapped.message,
        timestamp: new Date().toISOString(),
      };
    }

    return {
      statusCode: HttpStatus.BAD_REQUEST,
      error: 'Bad Request',
      message: err.message || 'Erro na operação com o banco de dados.',
      timestamp: new Date().toISOString(),
    };
  }

  private getErrorName(status: number): string {
    const names: Record<number, string> = {
      400: 'Bad Request',
      401: 'Unauthorized',
      403: 'Forbidden',
      404: 'Not Found',
      409: 'Conflict',
      422: 'Unprocessable Entity',
      500: 'Internal Server Error',
    };
    return names[status] || 'Error';
  }
}
