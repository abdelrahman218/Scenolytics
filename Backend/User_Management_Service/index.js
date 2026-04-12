import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import routes from './routes/index.js';
import { connectRabbitMQ, closeRabbitMQ } from './utils/rabbitmq.js';
import { initializeEventListeners } from './utils/eventListener.js';

dotenv.config({filepath: `./.env`});

const app = express();
const PORT = process.env.USER_MANAGEMENT_SERVICE_PORT || 5002;

// Middleware
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Routes
app.use('/', routes);

// Error handling middleware
app.use((err, req, res, next) => {
  res.status(err.status || 500).json({
    message: err.message || 'Internal server error',
    error: process.env.NODE_ENV === 'development' ? err : undefined
  });
});

// Start server
const server = app.listen(PORT, () => {
  
  // Connect to RabbitMQ asynchronously with retry logic (non-blocking)
  const connectWithRetry = async (retries = 10, delay = 3000) => {
    for (let attempt = 1; attempt <= retries; attempt++) {
      try {
        await connectRabbitMQ();
        
        await initializeEventListeners();
        
        return;
      } catch (error) {
        
        if (attempt < retries) {
          
          await new Promise(resolve => setTimeout(resolve, delay));
        } else {
          console.error('[STARTUP] Failed to connect to RabbitMQ after all retries.');
        }
      }
    }
  };
  
  // Start retry process in background (non-blocking)
  connectWithRetry().catch(err => {
    console.error('[STARTUP] Unexpected error in connectWithRetry:', err);
  });
});

// Graceful shutdown
process.on('SIGTERM', async () => {
  server.close(async () => {
    await closeRabbitMQ();
    process.exit(0);
  });
});
