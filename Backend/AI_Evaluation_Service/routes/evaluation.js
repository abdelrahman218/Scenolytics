import express from 'express';
import { validateEvaluation, validateScores } from '../validators/evaluation.js';
import * as evaluationService from '../services/evaluationService.js';

const router = express.Router();

// Create evaluation
router.post('/evaluations', async (req, res, next) => {
  try {
    const validation = validateEvaluation(req.body);
    if (!validation.isValid) {
      return res.status(400).json({ errors: validation.errors });
    }

    const evaluation = await evaluationService.createEvaluation(req.body.media_id, req.body.submission_id);
    res.status(201).json(evaluation);
  } catch (error) {
    next(error);
  }
});

// Get evaluation
router.get('/evaluations/:evaluation_id', async (req, res, next) => {
  try {
    const evaluation = await evaluationService.getEvaluationById(req.params.evaluation_id);
    res.status(200).json(evaluation);
  } catch (error) {
    error.status = 404;
    next(error);
  }
});

// Update evaluation scores
router.patch('/evaluations/:evaluation_id/scores', async (req, res, next) => {
  try {
    const validation = validateScores(req.body);
    if (!validation.isValid) {
      return res.status(400).json({ errors: validation.errors });
    }

    const evaluation = await evaluationService.updateEvaluationScores(req.params.evaluation_id, req.body);
    res.status(200).json(evaluation);
  } catch (error) {
    next(error);
  }
});

// Update evaluation feedback
router.patch('/evaluations/:evaluation_id/feedback', async (req, res, next) => {
  try {
    const { feedback, detected_emotions } = req.body;
    if (!feedback) {
      return res.status(400).json({ message: 'feedback is required' });
    }

    const evaluation = await evaluationService.updateEvaluationFeedback(req.params.evaluation_id, feedback, detected_emotions);
    res.status(200).json(evaluation);
  } catch (error) {
    next(error);
  }
});

// Get pending evaluations
router.get('/evaluations/queue/pending', async (req, res, next) => {
  try {
    const evaluations = await evaluationService.getPendingEvaluations();
    res.status(200).json(evaluations);
  } catch (error) {
    next(error);
  }
});

// Handle evaluation error
router.patch('/evaluations/:evaluation_id/error', async (req, res, next) => {
  try {
    const { error_message } = req.body;
    const evaluation = await evaluationService.handleEvaluationError(req.params.evaluation_id, error_message);
    res.status(200).json(evaluation);
  } catch (error) {
    next(error);
  }
});

export default router;
