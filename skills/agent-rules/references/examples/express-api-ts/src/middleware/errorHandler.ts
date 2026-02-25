import type { Request, Response, NextFunction } from 'express';
import { AppError } from '../utils/errors.js';
import { logger } from '../utils/logger.js';
import { config } from '../config.js';

interface ErrorResponse {
  error: {
    message: string;
    code?: string;
    details?: unknown;
    stack?: string;
  };
}

export function errorHandler(
  err: Error,
  _req: Request,
  res: Response<ErrorResponse>,
  _next: NextFunction
): void {
  logger.error('Request error', { error: err.message, stack: err.stack });

  if (err instanceof AppError) {
    res.status(err.statusCode).json({
      error: {
        message: err.message,
        code: err.code,
        details: err.details,
      },
    });
    return;
  }

  // Unknown error - don't leak internals in production
  const message = config.isProd ? 'Internal server error' : err.message;
  const response: ErrorResponse = {
    error: { message },
  };

  if (!config.isProd) {
    response.error.stack = err.stack;
  }

  res.status(500).json(response);
}
