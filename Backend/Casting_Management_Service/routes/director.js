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
import {
  checkRequiredFieldsCreateAudition,
  checkRequiredFieldsReviewSubmission,
  checkSubmissionExists,
  checkValidValuesAuditionData,
  checkValidValuesReviewSubmission,
} from "../validators/director.js";
import { checkAuditionExists } from "../validators/general.js";

const router = express.Router();

// ==================== AUDITION ENDPOINTS ====================
// Get Audition for Director
router.get("/auditions/:audition_id", getDirectorAudition);

// Create audition
const createAuditionValidators = [
  checkRequiredFieldsCreateAudition,
  checkValidValuesAuditionData,
];
router.post(
  "/auditions/create_audition",
  createAuditionValidators,
  createAudition,
);

// Get director's auditions
router.get("/auditions", getAllDirectorAuditions);

// Update audition
const updateAudtionValidators = [
  checkAuditionExists,
  checkValidValuesAuditionData,
];
router.patch(
  "/auditions/:audition_id",
  updateAudtionValidators,
  updateAudition,
);

// Delete audition
const deleteAudtionValidators = [checkAuditionExists];
router.delete(
  "/auditions/:audition_id",
  deleteAudtionValidators,
  deleteAudition,
);

// ==================== INVITATION ENDPOINTS ====================

// Invite actors to audition
const inviteActorsToAuditionValidators = [checkAuditionExists];
router.post("/auditions/:audition_id/invite_actors", inviteActorsToAudition);

// Get director's pending invitations for specific audition
router.get(
  "/auditions/:audition_id/invitations/pending",
  getAuditionPendingInvitations,
);

// Get director's pending invitations
router.get("/invitations/pending", getDirectorPendingInvitations);

// Get list of actors for audition
router.get("/auditions/:audition_id/actors", getActorsForAudition);

// ==================== SUBMISSION ENDPOINTS ====================

// Get submissions for audition
router.get("/auditions/:audition_id/submissions", getAuditionSubmissions);

// Director reviews submission
const reviewSubmissionValidators = [
  checkRequiredFieldsReviewSubmission,
  checkValidValuesReviewSubmission,
  checkSubmissionExists,
];
router.patch(
  "/submissions/:submission_id/review",
  reviewSubmissionValidators,
  reviewSubmission,
);

export default router;
