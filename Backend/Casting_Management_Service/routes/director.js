import express from "express";
import {
  createAudition,
  deleteAudition,
  getActorsForAudition,
  getAuditionSubmissions,
  getDirectorAudition,
  getAllDirectorAuditions,
  getDirectorPendingInvitations,
  inviteActorsToAudition,
  reviewSubmission,
  updateAudition,
  getAuditionPendingInvitations,
} from "../services/director.js";

const router = express.Router();

// ==================== AUDITION ENDPOINTS ====================
// Get Audition for Director
router.get("/auditions/:audition_id", getDirectorAudition);

// Create audition
router.post("/auditions/create_audition", createAudition);

// Get director's auditions
router.get("/auditions", getAllDirectorAuditions);

// Update audition
router.patch("/auditions/:audition_id", updateAudition);

// Delete audition
router.delete("/auditions/:audition_id", deleteAudition);

// ==================== INVITATION ENDPOINTS ====================

// Invite actors to audition
router.post("/auditions/:audition_id/invite_actors", inviteActorsToAudition);

// Get director's pending invitations for specific audition
router.get(
    "/auditions/:audition_id/invitations/pending",
    getAuditionPendingInvitations,
);

// Get director's pending invitations
router.get(
  "/invitations/pending",  
  getDirectorPendingInvitations,
);  

// Get list of actors for audition
router.get("/auditions/:audition_id/actors", getActorsForAudition);

// ==================== SUBMISSION ENDPOINTS ====================

// Get submissions for audition
router.get("/auditions/:audition_id/submissions", getAuditionSubmissions);

// Director reviews submission
router.patch("/submissions/:submission_id/review", reviewSubmission);

export default router;