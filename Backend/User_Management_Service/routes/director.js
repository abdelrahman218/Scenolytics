import express from 'express';
import { validateDirectorProfile } from '../validators/profile.js';
import { validateJWTToken, validateDirectorRole, validateProfileAccess } from '../validators/roleAndAccess.js';
import * as directorService from '../services/directorService.js';

const router = express.Router();

// ==================== DIRECTOR PROFILE ROUTES ====================

/**
 * POST /directors/profile
 * Create a new director profile
 */
router.post('/directors/profile', validateJWTToken, validateDirectorRole, async (req, res, next) => {
  try {
    const validation = validateDirectorProfile(req.body);
    if (!validation.isValid) {
      return res.status(400).json({ errors: validation.errors });
    }

    // Ensure user can only create profile for themselves
    if (req.user.user_id !== req.body.user_id) {
      return res.status(403).json({ message: 'You can only create a profile for yourself' });
    }

    const profile = await directorService.createDirectorProfile(req.body.user_id, req.body);
    res.status(201).json(profile);
  } catch (error) {
    next(error);
  }
});

/**
 * GET /directors/:user_id/profile
 * Get director profile by user_id
 */
router.get('/directors/:user_id/profile', validateJWTToken, async (req, res, next) => {
  try {
    const profile = await directorService.getDirectorProfile(req.params.user_id);
    res.status(200).json(profile);
  } catch (error) {
    error.status = 404;
    next(error);
  }
});

/**
 * PATCH /directors/profile/:profile_id
 * Update director profile (only profile owner can update)
 */
router.patch('/directors/profile/:profile_id', validateJWTToken, validateDirectorRole, async (req, res, next) => {
  try {
    const validation = validateDirectorProfile({ ...req.body, user_id: req.user.user_id });
    if (!validation.isValid) {
      return res.status(400).json({ errors: validation.errors });
    }

    const profile = await directorService.updateDirectorProfile(req.params.profile_id, req.body);
    res.status(200).json(profile);
  } catch (error) {
    next(error);
  }
});

/**
 * DELETE /directors/profile/:profile_id
 * Delete director profile - now handled by Identity Provider Service through USER_DELETED event
 * This endpoint is deprecated
 */
router.delete('/directors/profile/:profile_id', validateJWTToken, validateDirectorRole, async (req, res, next) => {
  return res.status(410).json({ 
    message: 'Profile deletion is now handled through account deletion via Identity Provider Service',
    deprecated: true 
  });
});

export default router;
