import express from 'express';
import { config } from './config.js';
import { logger } from './utils/logger.js';
import { errorHandler } from './middleware/errorHandler.js';
import { requestLogger } from './middleware/requestLogger.js';
import { userRoutes } from './routes/users.js';
import { healthRoutes } from './routes/health.js';

const app = express();

// Middleware
app.use(express.json());
app.use(requestLogger);

// Routes
app.use('/api/users', userRoutes);
app.use('/health', healthRoutes);

// Error handling (must be last)
app.use(errorHandler);

app.listen(config.port, () => {
  logger.info(`Server running on port ${config.port}`);
});

export { app };
