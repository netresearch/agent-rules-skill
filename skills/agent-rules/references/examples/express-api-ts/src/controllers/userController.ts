import type { Request, Response, NextFunction } from 'express';
import { z } from 'zod';
import { AppError } from '../utils/errors.js';

const createUserSchema = z.object({
  email: z.string().email(),
  name: z.string().min(1).max(100),
});

const updateUserSchema = createUserSchema.partial();

// In-memory store for demo purposes
const users = new Map<string, { id: string; email: string; name: string }>();

export class UserController {
  getAll = async (_req: Request, res: Response): Promise<void> => {
    const allUsers = Array.from(users.values());
    res.json({ data: allUsers });
  };

  getById = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    const user = users.get(req.params.id ?? '');
    if (!user) {
      next(new AppError('User not found', 404));
      return;
    }
    res.json({ data: user });
  };

  create = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    const parsed = createUserSchema.safeParse(req.body);
    if (!parsed.success) {
      next(new AppError('Validation failed', 400, parsed.error.flatten()));
      return;
    }

    const id = crypto.randomUUID();
    const user = { id, ...parsed.data };
    users.set(id, user);

    res.status(201).json({ data: user });
  };

  update = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    const id = req.params.id ?? '';
    const existing = users.get(id);
    if (!existing) {
      next(new AppError('User not found', 404));
      return;
    }

    const parsed = updateUserSchema.safeParse(req.body);
    if (!parsed.success) {
      next(new AppError('Validation failed', 400, parsed.error.flatten()));
      return;
    }

    const updated = { ...existing, ...parsed.data };
    users.set(id, updated);

    res.json({ data: updated });
  };

  delete = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    const id = req.params.id ?? '';
    if (!users.has(id)) {
      next(new AppError('User not found', 404));
      return;
    }

    users.delete(id);
    res.status(204).send();
  };
}
