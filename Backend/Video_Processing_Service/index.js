import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import mediaRoutes from './routes/media.js';
import { connectRabbitMQ, closeRabbitMQ } from './utils/rabbitmq.js';
import { connectRedis, closeRedis } from './utils/redis.js';

dotenv.config({filepath: `./.env`});

const app = express();
const PORT = process.env.VIDEO_PROCESSING_SERVICE_PORT || 5002;

// Middleware
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Routes
app.use('/', mediaRoutes);

// Error handling middleware
app.use((err, req, res, next) => {
  res.status(err.status || 500).json({
    message: err.message || 'Internal server error',
    error: process.env.NODE_ENV === 'development' ? err : undefined
  });
});

// Start server
const server = app.listen(PORT, async () => {
  console.log(`Video Processing Service running on port: ${PORT}`);
  
  // Connect to RabbitMQ
  try {
    await connectRabbitMQ();
  } catch (error) {
    console.error('Failed to connect to RabbitMQ:', error);
  }

  // Connect to Redis
  try {
    await connectRedis();
  } catch (error) {
    console.error('Failed to connect to Redis:', error);
  }
});

// Graceful shutdown
process.on('SIGTERM', async () => {
  console.log('SIGTERM received, shutting down gracefully');
  server.close(async () => {
    await closeRabbitMQ();
    await closeRedis();
    process.exit(0);
  });
});
