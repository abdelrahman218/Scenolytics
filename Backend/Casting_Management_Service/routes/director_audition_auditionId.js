import express from "express";
import {
  deleteAudition,
  getActorsForAudition,
  getAuditionSubmissions,
  inviteActorsToAudition,
  reviewSubmission,
  updateAudition,
  getAuditionPendingInvitations,
  getAuditionCallbacks,
  rescheduleCallback,
  createNewCallbackMeeting,
  reviewCallback,
} from "../services/director.js";
import {
  checkCallbackExists,
  checkRequiredFieldsRescheduleCallback,
  checkRequiredFieldsReviewCallback,
  checkRequiredFieldsReviewSubmission,
  checkSubmissionExists,
  checkValidValuesAuditionData,
  checkValidValuesReviewCallback,
  checkValidValuesReviewSubmission,
} from "../validators/director.js";

const router = express.Router({ mergeParams: true });

// ==================== AUDITION ENDPOINTS ====================

// Update audition
const updateAudtionValidators = [
  checkValidValuesAuditionData,
];
router.patch(
  "/",
  updateAudtionValidators,
  updateAudition,
);

// Delete audition
router.delete(
  "/",
  deleteAudition,
);

// ==================== INVITATION ENDPOINTS ====================

// Invite actors to audition
router.post(
  "/invite_actors",
  inviteActorsToAudition,
);

// Get director's pending invitations for specific audition
router.get(
  "/invitations/pending",
  getAuditionPendingInvitations,
);

// Get list of actors for audition
router.get("/actors", getActorsForAudition);

// ==================== SUBMISSION ENDPOINTS ====================

// Get submissions for audition
router.get("/submissions", getAuditionSubmissions);

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

// ==================== CALLBACK ENDPOINTS ====================

// Get callbacks for audition
router.get("/callbacks", getAuditionCallbacks);

// Reschedule callback
const rescheduleCallbackValidators = [
  checkCallbackExists,
  checkRequiredFieldsRescheduleCallback,
];
router.patch(
  "/callbacks/:callback_id/reschedule",
  rescheduleCallbackValidators,
  rescheduleCallback,
);

// Create new callback meeting
const createNewCallbackMeetingValidators = [checkCallbackExists];
router.patch(
  "/callbacks/:callback_id/new_meeting",
  createNewCallbackMeetingValidators,
  createNewCallbackMeeting,
);

// Review callback
const reviewCallbackValidators = [
  checkCallbackExists,
  checkRequiredFieldsReviewCallback,
  checkValidValuesReviewCallback,
];
router.patch(
  "/callbacks/:callback_id/review",
  reviewCallbackValidators,
  reviewCallback,
);

export default router;
