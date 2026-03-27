import express from "express";
import {
  getActorAudition,
  getActorInvitations,
  getActorSubmissions,
  respondToInvitation,
  submitAuditionSubmission,
} from "../services/actor.js";

const router = express.Router();

// ==================== INVITATION ENDPOINTS ====================
// Get Audition for Actor
router.get("/auditions/:audition_id", getActorAudition);

// Get invitations for actor
router.get("/invitations", getActorInvitations);

// Actor responds to invitation
router.patch("/invitations/:invitation_id/respond", respondToInvitation);

// ==================== SUBMISSION ENDPOINTS ====================

// Get submissions for actor
router.get("/auditions/submissions", getActorSubmissions);

// Submit audition submission
router.post("/auditions/:audition_id/submissions", submitAuditionSubmission);

export default router;