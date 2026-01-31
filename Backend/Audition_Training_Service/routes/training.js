import express from 'express';
import { validateTrainingSession, validateFeedback } from '../validators/training.js';
import * as trainingService from '../services/trainingService.js';

const router = express.Router();

// Start training session
router.post('/sessions', async (req, res, next) => {
  try {
    const validation = validateTrainingSession(req.body);
    if (!validation.isValid) {
      return res.status(400).json({ errors: validation.errors });
    }

    const session = await trainingService.startTrainingSession(req.body.actor_id, req.body.media_id);
    res.status(201).json(session);
  } catch (error) {
    next(error);
  }
});

// Get training session
router.get('/sessions/:session_id', async (req, res, next) => {
  try {
    const session = await trainingService.getTrainingSession(req.params.session_id);
    res.status(200).json(session);
  } catch (error) {
    error.status = 404;
    next(error);
  }
});

// Get actor sessions
router.get('/actors/:actor_id/sessions', async (req, res, next) => {
  try {
    const sessions = await trainingService.getActorSessions(req.params.actor_id);
    res.status(200).json(sessions);
  } catch (error) {
    next(error);
  }
});

// End training session
router.patch('/sessions/:session_id/end', async (req, res, next) => {
  try {
    const { duration } = req.body;
    if (!duration) {
      return res.status(400).json({ message: 'duration is required' });
    }

    const session = await trainingService.endTrainingSession(req.params.session_id, duration);
    res.status(200).json(session);
  } catch (error) {
    next(error);
  }
});

// Add real-time feedback
router.post('/sessions/:session_id/feedback', async (req, res, next) => {
  try {
    const validation = validateFeedback({ session_id: req.params.session_id, feedback_type: req.body.feedback_type });
    if (!validation.isValid) {
      return res.status(400).json({ errors: validation.errors });
    }

    const feedback = await trainingService.addRealTimeFeedback(
      req.params.session_id,
      req.body.feedback_type,
      req.body.feedback_message,
      req.body.timestamp_seconds,
      req.body.emotion_detected,
      req.body.emotion_confidence
    );
    res.status(201).json(feedback);
  } catch (error) {
    next(error);
  }
});

// Get session feedback
router.get('/sessions/:session_id/feedback', async (req, res, next) => {
  try {
    const feedback = await trainingService.getSessionFeedback(req.params.session_id);
    res.status(200).json(feedback);
  } catch (error) {
    next(error);
  }
});

// Add training recommendation
router.post('/sessions/:session_id/recommendations', async (req, res, next) => {
  try {
    const recommendation = await trainingService.addTrainingRecommendation(
      req.params.session_id,
      req.body.recommendation_text,
      req.body.recommendation_category,
      req.body.priority
    );
    res.status(201).json(recommendation);
  } catch (error) {
    next(error);
  }
});

// Get session recommendations
router.get('/sessions/:session_id/recommendations', async (req, res, next) => {
  try {
    const recommendations = await trainingService.getSessionRecommendations(req.params.session_id);
    res.status(200).json(recommendations);
  } catch (error) {
    next(error);
  }
});

export default router;
