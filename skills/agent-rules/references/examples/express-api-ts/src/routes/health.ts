import { Router, type Request, type Response } from 'express';

const router = Router();

router.get('/', (_req: Request, res: Response) => {
  res.json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
  });
});

router.get('/ready', (_req: Request, res: Response) => {
  // Add database connectivity check here
  res.json({ ready: true });
});

export { router as healthRoutes };
