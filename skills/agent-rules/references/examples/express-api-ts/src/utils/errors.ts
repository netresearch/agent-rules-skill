export class AppError extends Error {
  public readonly statusCode: number;
  public readonly code?: string;
  public readonly details?: unknown;

  constructor(message: string, statusCode: number = 500, details?: unknown, code?: string) {
    super(message);
    this.name = 'AppError';
    this.statusCode = statusCode;
    this.code = code;
    this.details = details;

    // Maintain proper stack trace
    Error.captureStackTrace(this, this.constructor);
  }

  static badRequest(message: string, details?: unknown): AppError {
    return new AppError(message, 400, details, 'BAD_REQUEST');
  }

  static unauthorized(message = 'Unauthorized'): AppError {
    return new AppError(message, 401, undefined, 'UNAUTHORIZED');
  }

  static forbidden(message = 'Forbidden'): AppError {
    return new AppError(message, 403, undefined, 'FORBIDDEN');
  }

  static notFound(resource = 'Resource'): AppError {
    return new AppError(`${resource} not found`, 404, undefined, 'NOT_FOUND');
  }

  static conflict(message: string): AppError {
    return new AppError(message, 409, undefined, 'CONFLICT');
  }

  static internal(message = 'Internal server error'): AppError {
    return new AppError(message, 500, undefined, 'INTERNAL_ERROR');
  }
}
