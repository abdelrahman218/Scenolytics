import express from 'express';
import multer from 'multer';
import { validateMediaUpload, getMediaType } from '../validators/media.js';
import * as mediaService from '../services/media.js';
import * as processingJobService from '../services/processingJob.js';

const router = express.Router();
const upload = multer({ storage: multer.memoryStorage() });

// Upload media
router.post('/upload', upload.single('file'), async (req, res, next) => {
  try {
    const { user_id } = req.body;

    if (!user_id) {
      return res.status(400).json({ message: 'user_id is required' });
    }

    if (!req.file) {
      return res.status(400).json({ message: 'No file provided' });
    }

    const validation = validateMediaUpload(req.file);
    if (!validation.isValid) {
      return res.status(400).json({ errors: validation.errors });
    }

    const media = await mediaService.uploadMedia(req.file, user_id);
    res.status(201).json(media);
  } catch (error) {
    next(error);
  }
});

// Get media by ID
router.get('/media/:media_id', async (req, res, next) => {
  try {
    const media = await mediaService.getMediaById(req.params.media_id);
    res.status(200).json(media);
  } catch (error) {
    error.status = 404;
    next(error);
  }
});

// Get user's media
router.get('/user/:user_id/media', async (req, res, next) => {
  try {
    const media = await mediaService.getUserMedia(req.params.user_id);
    res.status(200).json(media);
  } catch (error) {
    next(error);
  }
});

// Delete media
router.delete('/media/:media_id', async (req, res, next) => {
  try {
    const result = await mediaService.deleteMedia(req.params.media_id);
    res.status(200).json(result);
  } catch (error) {
    error.status = 404;
    next(error);
  }
});

// Create processing job
router.post('/jobs', async (req, res, next) => {
  try {
    const { media_id, job_type, priority } = req.body;

    if (!media_id || !job_type) {
      return res.status(400).json({ message: 'media_id and job_type are required' });
    }

    const job = await processingJobService.createProcessingJob(media_id, job_type, priority || 5);
    res.status(201).json(job);
  } catch (error) {
    next(error);
  }
});

// Get job status
router.get('/jobs/:job_id', async (req, res, next) => {
  try {
    const job = await processingJobService.getJobStatus(req.params.job_id);
    res.status(200).json(job);
  } catch (error) {
    error.status = 404;
    next(error);
  }
});

// Get media jobs
router.get('/media/:media_id/jobs', async (req, res, next) => {
  try {
    const jobs = await processingJobService.getMediaJobs(req.params.media_id);
    res.status(200).json(jobs);
  } catch (error) {
    next(error);
  }
});

// Get queued jobs
router.get('/jobs/queue/pending', async (req, res, next) => {
  try {
    const jobs = await processingJobService.getQueuedJobs();
    res.status(200).json(jobs);
  } catch (error) {
    next(error);
  }
});

// Update job status
router.patch('/jobs/:job_id', async (req, res, next) => {
  try {
    const { status, result, error_message } = req.body;

    if (!status) {
      return res.status(400).json({ message: 'status is required' });
    }

    const job = await processingJobService.updateJobStatus(req.params.job_id, status, result, error_message);
    res.status(200).json(job);
  } catch (error) {
    error.status = 404;
    next(error);
  }
});

export default router;
