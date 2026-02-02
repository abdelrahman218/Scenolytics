import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import notificationRoutes from './routes/notification.js';
import { connectRabbitMQ, closeRabbitMQ, EXCHANGES, QUEUES, ROUTING_KEYS, assertExchange, assertQueue, bindQueue, consumeMessages } from './utils/rabbitmq.js';
import { setupEventSubscribers } from './services/eventSubscriber.js';

dotenv.config({filepath: `./.env`});

const app = express();
const PORT = process.env.NOTIFICATION_SERVICE_PORT || 5005;

// Middleware
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Routes
app.use('/', notificationRoutes);

// Error handling middleware
app.use((err, req, res, next) => {
  res.status(err.status || 500).json({
    message: err.message || 'Internal server error',
    error: process.env.NODE_ENV === 'development' ? err : undefined
  });
});

// Start server
const server = app.listen(PORT, async () => {
  console.log(`Notification Service running on port: ${PORT}`);
  
  // Connect to RabbitMQ
  try {
    await connectRabbitMQ();
    
    // Setup event subscribers
    await setupEventSubscribers();
  } catch (error) {
    console.error('Failed to setup RabbitMQ subscribers:', error);
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
