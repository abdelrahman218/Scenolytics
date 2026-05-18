import { checkRequiredFields, checkValidValues } from "./general.js";
import { AuditionSubmission } from "../models/audition_submission.js";
import { Callback } from "../models/callback.js";
import { Audition } from "../models/audition.js";
import { GoogleCalendarCredentials } from "../models/google_calender_credentials.js";

// Check Authorization

export const checkDirectorOwnershipOfAudition = async(req, res, next) => {
    const audition = await Audition.findById(req.params.audition_id);

    if (audition.director_id !== req.user.user_id) {
        return res.status(403).json({ message: 'You are not authorized to perform this action' });
    }

    next();
};

// Checking Required Fields for each endpoint

export const checkRequiredFieldsCreateAudition = checkRequiredFields(['title', 'type', 'candidate_min_age', 'candidate_max_age']);

export const checkRequiredFieldsInviteActorsToAudition = checkRequiredFields(['actor_ids']);

export const checkRequiredFieldsReviewSubmission = checkRequiredFields(['status']);

export const checkRequiredFieldsRescheduleCallback = checkRequiredFields(['callback_datetime']);

export const checkRequiredFieldsReviewCallback = checkRequiredFields(['status']);

// Checking Valid Values

export const checkValidValuesAuditionData = checkValidValues({type: ['Audio', 'Video'], candidate_gender: ['Male', 'Female', 'Both'], candidate_ethnicity: ['White', 'Black', 'Asian', 'Arab', 'Any'], candidate_body_type: ['Slim', 'Athletic', 'Average', 'Heavyset', 'Any']});

export const checkValidValuesReviewSubmission = checkValidValues({status: ['accepted', 'rejected']});

export const checkValidValuesReviewCallback = checkValidValues({status: ['accepted', 'rejected']});

// Other Validators

export const checkCallbackExists = async(req, res, next) => {
    const callback = await Callback.findById(req.params.callback_id);
    if (!callback) {
        return res.status(404).json({ message: 'Callback not found' });
    }
    next();
};

export const checkSubmissionExists = async(req, res, next) => {
    const submission = await AuditionSubmission.findById(req.params.submission_id);
    if (!submission) {
        return res.status(404).json({ message: 'Submission not found' });
    }
    next();
};

export const checkSubmissionIsPendingOrUnderReview = async(req, res, next) => {
    const submission = await AuditionSubmission.findById(req.params.submission_id);
    if (submission.status !== 'pending' && submission.status !== 'under_review') {
        return res.status(400).json({ message: `Submission is already ${submission.status}` });
    }
    next();
};

export const checkDateTimeExistsWhenSubmissionAccepted = async(req, res, next) => {
    if (req.body.status === 'accepted' && !req.body.callback_datetime) {
        return res.status(400).json({ message: 'Callback datetime required' });
    }
    next();
};

export const checkCallbackIsScheduled = async(req, res, next) => {
    const callback = await Callback.findById(req.params.callback_id);
    
    if (callback.callback_status !== 'scheduled') {
        return res.status(400).json({ message: `Callback is already ${callback.callback_status}` });
    }
    next();
};

export const checkDirectorConnectedToGoogle = async(req, res, next) => {
    const googleCredentials = await GoogleCalendarCredentials.findByDirectorId(req.user.user_id);
    
    if (!googleCredentials) {
        return res.status(400).json({ message: 'Director is not connected to Google' });
    }

    next();
};