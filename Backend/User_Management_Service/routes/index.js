import express from 'express';
import actorRoutes from './actor.js';
import directorRoutes from './director.js';

const router = express.Router();

// ==================== ROUTES ====================
// Actor routes
router.use('', actorRoutes);

// Director routes
router.use('', directorRoutes);

export default router;
