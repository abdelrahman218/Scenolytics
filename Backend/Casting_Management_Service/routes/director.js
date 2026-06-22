import express from "express";
import {
  createAudition,
  getAllDirectorAuditions,
  getDirectorPendingInvitations,
  connectGoogleMeet,
  connectGoogleMeetAuthUrl,
  disconnectGoogleMeet,
  getGoogleMeetConnectionStatus
} from "../services/director.js";
import {
  checkDirectorOwnershipOfAudition,
  checkRequiredFieldsCreateAudition,
  checkValidValuesAuditionData,
  checkValidValuesAuditionScriptEmotions,
} from "../validators/director.js";
import { checkAuditionExists } from "../validators/general.js";
import directorAuditionRouter from "./director_audition_auditionId.js";

const router = express.Router();

// ==================== AUDITION ENDPOINTS ====================
// Create audition
const createAuditionValidators = [
  checkRequiredFieldsCreateAudition,
  checkValidValuesAuditionData,
  checkValidValuesAuditionScriptEmotions
];
router.post(
  "/auditions/create_audition",
  createAuditionValidators,
  createAudition,
);

// Get director's auditions
router.get("/auditions", getAllDirectorAuditions);

// Router for specific audition
const directorAuditionRouterValidators = [
  checkAuditionExists,
  checkDirectorOwnershipOfAudition,
];
router.use(
  "/auditions/:audition_id",
  directorAuditionRouterValidators,
  directorAuditionRouter,
);

// ==================== INVITATION ENDPOINTS ====================

// Get director's pending invitations
router.get("/invitations/pending", getDirectorPendingInvitations);

// ==================== GOOGLE CALENDAR ENDPOINTS ====================

router.get("/google/connect", connectGoogleMeet);
router.get("/google/connect-url", connectGoogleMeetAuthUrl);
router.get("/google/connection-status", getGoogleMeetConnectionStatus);
router.delete("/google/disconnect", disconnectGoogleMeet);

export default router;
