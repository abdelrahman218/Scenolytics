import express from 'express';
import { validateActorProfile, validateActorProfileValues } from '../validators/profile.js';
import { validateJWTToken, validateActorRole, validateProfileAccess, validateProfileOwnership } from '../validators/roleAndAccess.js';
import * as actorService from '../services/actorService.js';

const router = express.Router();

// ==================== ACTOR PROFILE ROUTES ====================

/**
 * POST /actors/profile
 * Create a new actor profile
 */
router.post('/actors/profile', validateJWTToken, validateActorRole, async (req, res, next) => {
  try {
    const validation = validateActorProfile(req.body);
    if (!validation.isValid) {
      return res.status(400).json({ errors: validation.errors });
    }

    // Ensure user can only create profile for themselves
    if (req.user.user_id !== req.body.user_id) {
      return res.status(403).json({ message: 'You can only create a profile for yourself' });
    }

    const profile = await actorService.createActorProfile(req.body.user_id, req.body);
    res.status(201).json(profile);
  } catch (error) {
    next(error);
  }
});

/**
 * GET /actors/:user_id/profile
 * Get actor profile by user_id
 */
router.get('/actors/:user_id/profile', validateJWTToken, validateProfileAccess, async (req, res, next) => {
  try {
    const profile = await actorService.getActorProfile(req.params.user_id);
    res.status(200).json(profile);
  } catch (error) {
    error.status = 404;
    next(error);
  }
});

/**
 * PATCH /actors/profile/:profile_id
 * Update actor profile (only profile owner can update)
 */
router.patch('/actors/profile/:profile_id', validateJWTToken, validateActorRole, async (req, res, next) => {
  try {
    const validation = validateActorProfile({ ...req.body, user_id: req.user.user_id });
    if (!validation.isValid) {
      return res.status(400).json({ errors: validation.errors });
    }

    const profile = await actorService.updateActorProfile(req.params.profile_id, req.body);
    res.status(200).json(profile);
  } catch (error) {
    next(error);
  }
});

/**
 * DELETE /actors/profile/:profile_id
 * Delete actor profile - now handled by Identity Provider Service through USER_DELETED event
 * This endpoint is deprecated
 */
router.delete('/actors/profile/:profile_id', validateJWTToken, validateActorRole, async (req, res, next) => {
  return res.status(410).json({ 
    message: 'Profile deletion is now handled through account deletion via Identity Provider Service',
    deprecated: true 
  });
});

/**
 * POST /actors/search
 * Search for actors by attributes (accessible to directors)
 */
router.post('/actors/search', validateJWTToken, async (req, res, next) => {
  try {
    // Only directors can search for actors
    if (req.user.role !== 'director') {
      return res.status(403).json({ message: 'Only directors can search for actors' });
    }

    const actors = await actorService.searchActors(req.body);
    res.status(200).json(actors);
  } catch (error) {
    next(error);
  }
});

export default router;
