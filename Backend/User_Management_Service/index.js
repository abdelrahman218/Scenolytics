import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import userRoutes from './routes/user.js';
import { connectRabbitMQ, closeRabbitMQ } from './utils/rabbitmq.js';

dotenv.config({filepath: `./.env`});

const app = express();
const PORT = process.env.USER_MANAGEMENT_SERVICE_PORT || 5002;

// Middleware
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Routes
app.use('/', userRoutes);

// Error handling middleware
app.use((err, req, res, next) => {
  res.status(err.status || 500).json({
    message: err.message || 'Internal server error',
    error: process.env.NODE_ENV === 'development' ? err : undefined
  });
});

// Start server
const server = app.listen(PORT, async () => {
  console.log(`User Management Service running on port: ${PORT}`);
  
  // Connect to RabbitMQ
  try {
    await connectRabbitMQ();
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
