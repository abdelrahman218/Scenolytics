import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import { connectRabbitMQ } from './utils/rabbitmq.js';
import authRoutes from './routes/auth.js';
import { assertExchange, EXCHANGES } from './utils/rabbitmq.js';

dotenv.config({filepath: `./.env`});

const app = express();
const PORT = process.env.IDENTITY_PROVIDER_SERVICE_PORT || 5000;

// Middleware
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Routes
app.use('/auth', authRoutes);

// Error handling middleware
app.use((err, req, res, next) => {
  res.status(err.status || 500).json({
    message: err.message || 'Internal server error',
    error: process.env.NODE_ENV === 'development' ? err : undefined
  });
});

// Start server
app.listen(PORT, async () => {
  console.log(`Server running on port: ${PORT}`);

  // Connect to RabbitMQ
  try {
    await connectRabbitMQ();
    await assertExchange(EXCHANGES.USERS);
    console.log("Connected to RabbitMQ Successfully");
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