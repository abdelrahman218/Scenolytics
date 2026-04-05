import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import directorRoutes from './routes/director.js';
import actorRoutes from './routes/actor.js';
import { connectRabbitMQ, closeRabbitMQ, assertExchange, EXCHANGES, QUEUES, assertQueue, bindQueue, ROUTING_KEYS } from './utils/rabbitmq.js';
import { validateActorAccess, validateDirectorAccess } from './validators/auth.js';
import { executeAsyncListeners } from './utils/asyncListeners.js';

dotenv.config({filepath: `./.env`});

const app = express();
const PORT = process.env.CASTING_MANAGEMENT_SERVICE_PORT || 5004;

// Middleware
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Routes
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
    Object.entries(EXCHANGES).forEach(async ([event, exchange]) => {
      await assertExchange(exchange);
    });
    
    Object.entries(QUEUES).forEach(async ([event, queue]) => {
      await assertQueue(queue);
    });

    Object.entries(ROUTING_KEYS).forEach(async ([event, routingKey]) => {
      const groupName = routingKey.slice(0, routingKey.indexOf('.'));

      await bindQueue(`${groupName}s_exchange`, `casting_management_${groupName}_events_queue`, routingKey);
    });

    executeAsyncListeners();
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
