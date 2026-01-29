import express from 'express';
import { validateActorProfile, validateDirectorProfile } from '../validators/profile.js';
import * as actorService from '../services/actorService.js';
import * as directorService from '../services/directorService.js';

const router = express.Router();

// Actor Profile Routes
router.post('/actors/profile', async (req, res, next) => {
  try {
    const validation = validateActorProfile(req.body);
    if (!validation.isValid) {
      return res.status(400).json({ errors: validation.errors });
    }

    const profile = await actorService.createActorProfile(req.body.user_id, req.body);
    res.status(201).json(profile);
  } catch (error) {
    next(error);
  }
});

router.get('/actors/:user_id/profile', async (req, res, next) => {
  try {
    const profile = await actorService.getActorProfile(req.params.user_id);
    res.status(200).json(profile);
  } catch (error) {
    error.status = 404;
    next(error);
  }
});

router.patch('/actors/profile/:profile_id', async (req, res, next) => {
  try {
    const profile = await actorService.updateActorProfile(req.params.profile_id, req.body);
    res.status(200).json(profile);
  } catch (error) {
    next(error);
  }
});

router.delete('/actors/profile/:profile_id', async (req, res, next) => {
  try {
    const result = await actorService.deleteActorProfile(req.params.profile_id);
    res.status(200).json(result);
  } catch (error) {
    next(error);
  }
});

router.post('/actors/search', async (req, res, next) => {
  try {
    const actors = await actorService.searchActors(req.body);
    res.status(200).json(actors);
  } catch (error) {
    next(error);
  }
});

// Director Profile Routes
router.post('/directors/profile', async (req, res, next) => {
  try {
    const validation = validateDirectorProfile(req.body);
    if (!validation.isValid) {
      return res.status(400).json({ errors: validation.errors });
    }

    const profile = await directorService.createDirectorProfile(req.body.user_id, req.body);
    res.status(201).json(profile);
  } catch (error) {
    next(error);
  }
});

router.get('/directors/:user_id/profile', async (req, res, next) => {
  try {
    const profile = await directorService.getDirectorProfile(req.params.user_id);
    res.status(200).json(profile);
  } catch (error) {
    error.status = 404;
    next(error);
  }
});

router.patch('/directors/profile/:profile_id', async (req, res, next) => {
  try {
    const profile = await directorService.updateDirectorProfile(req.params.profile_id, req.body);
    res.status(200).json(profile);
  } catch (error) {
    next(error);
  }
});

router.delete('/directors/profile/:profile_id', async (req, res, next) => {
  try {
    const result = await directorService.deleteDirectorProfile(req.params.profile_id);
    res.status(200).json(result);
  } catch (error) {
    next(error);
  }
});

export default router;
