import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import directorRoutes from './routes/director.js';
import actorRoutes from './routes/actor.js';
import generalRoutes from './routes/general.js';
import { connectRabbitMQ, closeRabbitMQ } from './utils/rabbitmq.js';
import { validateJWTToken, validateActorAccess, validateDirectorAccess } from './validators/auth.js';
import { setupAsyncListeners } from './utils/asyncListeners.js';

dotenv.config({filepath: `./.env`});

const app = express();
const PORT = process.env.CASTING_MANAGEMENT_SERVICE_PORT || 5004;

// Middleware
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Routes
app.use('', validateJWTToken, generalRoutes)
app.use('/director', validateDirectorAccess, directorRoutes);
app.use('/actor', validateActorAccess, actorRoutes);

// Error handling middleware
app.use((err, req, res, next) => {
  res.status(err.status || 500).json({
    message: err.message || 'Internal server error',
    error: process.env.NODE_ENV === 'development' ? err : undefined
  });
});

// Start server
const server = app.listen(PORT, async () => {
  console.log(`Casting Management Service running on port: ${PORT}`);
  
  // Connect to RabbitMQ
  try {
    await connectRabbitMQ();

    setupAsyncListeners();
  } catch (error) {
    console.error('Failed to connect to RabbitMQ:', error);
  }
});

// Graceful shutdown
process.on('SIGTERM', async () => {
  console.log('SIGTERM received, shutting down gracefully');
  server.close(async () => {
    await closeRabbitMQ();
    process.exit(0);
  });
});
