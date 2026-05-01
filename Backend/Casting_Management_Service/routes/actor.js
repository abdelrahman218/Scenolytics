import express from "express";
import {
  getActorPendingInvitations,
  getActorSubmissions,
  getAuditionPdfScript,
  respondToInvitation,
  submitAuditionSubmission,
} from "../services/actor.js";
import { checkAuditionExists, checkInvitationIsPending } from "../validators/general.js";
import {
  checkAuditionNotSubmitted,
  checkValidValuesRespondToInvitation,
} from "../validators/actor.js";

const router = express.Router();

// ==================== INVITATION ENDPOINTS ====================
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

// Get Pending invitations for actor
router.get("/invitations", getActorPendingInvitations);

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

// ==================== AUDITION ENDPOINTS ====================

// Get audition script as PDF
const getAuditionPdfScriptValidators = [
  checkAuditionExists,
]
router.get("/auditions/:audition_id/script", getAuditionPdfScriptValidators, getAuditionPdfScript);

export default router;
