import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import callbackRoutes from './routes/callback.js';

dotenv.config({filepath: `./.env`});

const app = express();
const PORT = process.env.CASTING_MANAGEMENT_SERVICE_PORT || 5004;

// Middleware
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Routes
app.use('/', callbackRoutes);

// Error handling middleware
app.use((err, req, res, next) => {
  res.status(err.status || 500).json({
    message: err.message || 'Internal server error',
    error: process.env.NODE_ENV === 'development' ? err : undefined
  });
});

// Start server
app.listen(PORT, () => {
  console.log(`Casting Management Service running on port: ${PORT}`);
});
