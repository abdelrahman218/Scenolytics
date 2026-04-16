import express from 'express';
import http from 'node:http';
import { Server } from 'socket.io';
import cors from 'cors';
import dotenv from 'dotenv';
import notificationRoutes from './routes/notification.js';
import { connectRabbitMQ, closeRabbitMQ } from './utils/rabbitmq.js';
import { setupAsyncListeners } from './utils/asyncListeners.js';
import { setupSocketServer } from './services/webSocketService.js';
import { validateJWTToken } from './validators/auth.js';

dotenv.config({filepath: `./.env`});

const app = express();
const socketio = new Server(process.env.WEB_SOCKET_PORT || 6001);
const PORT = process.env.NOTIFICATION_SERVICE_PORT || 5005;

// Middleware
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Routes
app.use('/', validateJWTToken, notificationRoutes);

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
    
    // Setup Async Listeners
    await setupAsyncListeners();
    
    // Setup Socket Server
    setupSocketServer(socketio);
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
