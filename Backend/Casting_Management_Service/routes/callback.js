import express from 'express';
import { validateCallback, validateSubmission } from '../validators/callback.js';
import * as callbackService from '../services/callbackService.js';

const router = express.Router();

// Send callback
router.post('/callbacks', async (req, res, next) => {
  try {
    const validation = validateCallback(req.body);
    if (!validation.isValid) {
      return res.status(400).json({ errors: validation.errors });
    }

    const callback = await callbackService.sendCallback(
      req.body.audition_id,
      req.body.director_id,
      req.body.actor_id,
      req.body.script_content,
      req.body.script_url
    );
    res.status(201).json(callback);
  } catch (error) {
    next(error);
  }
});

// Get callback
router.get('/callbacks/:callback_id', async (req, res, next) => {
  try {
    const callback = await callbackService.getCallback(req.params.callback_id);
    res.status(200).json(callback);
  } catch (error) {
    error.status = 404;
    next(error);
  }
});

// Get actor callbacks
router.get('/actors/:actor_id/callbacks', async (req, res, next) => {
  try {
    const callbacks = await callbackService.getActorCallbacks(req.params.actor_id);
    res.status(200).json(callbacks);
  } catch (error) {
    next(error);
  }
});

// Respond to callback
router.patch('/callbacks/:callback_id/respond', async (req, res, next) => {
  try {
    const { status } = req.body;
    if (!status) {
      return res.status(400).json({ message: 'status is required' });
    }

    const callback = await callbackService.respondToCallback(req.params.callback_id, status);
    res.status(200).json(callback);
  } catch (error) {
    next(error);
  }
});

// Submit callback video
router.post('/callbacks/:callback_id/submissions', async (req, res, next) => {
  try {
    const validation = validateSubmission({ callback_id: req.params.callback_id, media_id: req.body.media_id });
    if (!validation.isValid) {
      return res.status(400).json({ errors: validation.errors });
    }

    const submission = await callbackService.submitCallbackVideo(req.params.callback_id, req.body.media_id);
    res.status(201).json(submission);
  } catch (error) {
    next(error);
  }
});

// Get callback submissions
router.get('/callbacks/:callback_id/submissions', async (req, res, next) => {
  try {
    const submissions = await callbackService.getCallbackSubmissions(req.params.callback_id);
    res.status(200).json(submissions);
  } catch (error) {
    next(error);
  }
});

// Review callback submission
router.patch('/submissions/:submission_id/review', async (req, res, next) => {
  try {
    const { status, director_notes } = req.body;
    if (!status) {
      return res.status(400).json({ message: 'status is required' });
    }

    const submission = await callbackService.reviewCallbackSubmission(req.params.submission_id, status, director_notes);
    res.status(200).json(submission);
  } catch (error) {
    next(error);
  }
});

export default router;
