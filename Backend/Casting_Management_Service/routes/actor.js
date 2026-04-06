import express from "express";
import {
  getActorAudition,
  getActorPendingInvitations,
  getActorSubmissions,
  respondToInvitation,
  submitAuditionSubmission,
} from "../services/actor.js";
import { checkInvitationIsPending } from "../validators/general.js";
import {
  checkAuditionNotSubmitted,
  checkValidValuesRespondToInvitation,
} from "../validators/actor.js";

const router = express.Router();

// ==================== INVITATION ENDPOINTS ====================
// Get Audition for Actor
router.get("/auditions/:audition_id", getActorAudition);

// Get Pending invitations for actor
router.get("/invitations", getActorPendingInvitations);

// Actor responds to invitation
const respondToInvitationValidators = [
  checkInvitationIsPending,
  checkValidValuesRespondToInvitation,
];
router.patch(
  "/invitations/:invitation_id/respond",
  respondToInvitationValidators,
  respondToInvitation,
);

// ==================== SUBMISSION ENDPOINTS ====================

// Get submissions for actor
router.get("/auditions/submissions", getActorSubmissions);

// Submit audition submission
const submitAuditionSubmissionValidators = [
  checkAuditionNotSubmitted,
];
router.post(
  "/auditions/:audition_id/submissions",
  submitAuditionSubmissionValidators,
  submitAuditionSubmission,
);

export default router;
