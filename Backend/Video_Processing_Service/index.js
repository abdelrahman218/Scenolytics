import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import mediaRoutes from './routes/media.js';

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
app.listen(PORT, () => {
  console.log(`Video Processing Service running on port: ${PORT}`);
});
