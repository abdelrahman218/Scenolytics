import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import evaluationRoutes from './routes/evaluation.js';

dotenv.config({filepath: `./.env`});

const app = express();
const PORT = process.env.AI_EVALUATION_SERVICE_PORT || 5003;

// Middleware
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Routes
app.use('/', evaluationRoutes);

// Error handling middleware
app.use((err, req, res, next) => {
  res.status(err.status || 500).json({
    message: err.message || 'Internal server error',
    error: process.env.NODE_ENV === 'development' ? err : undefined
  });
});

// Start server
app.listen(PORT, () => {
  console.log(`AI Evaluation Service running on port: ${PORT}`);
});
