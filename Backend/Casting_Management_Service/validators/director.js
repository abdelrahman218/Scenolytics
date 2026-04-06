import { checkRequiredFields, checkValidValues } from "./general";
import { AuditionSubmission } from "../models/audition_submission";

// Checking Required Fields for each endpoint

export const checkRequiredFieldsCreateAudition = checkRequiredFields(['director_id', 'title', 'type', 'min_age', 'max_age', 'gender']);

export const checkRequiredFieldsInviteActorsToAudition = checkRequiredFields(['actor_ids']);

export const checkRequiredFieldsReviewSubmission = checkRequiredFields(['status']);

// Checking Valid Values

export const checkValidValuesAuditionData = checkValidValues({type: ['Audio', 'Video'], candidate_gender: ['Male', 'Female', 'Both'], candidate_ethnicity: ['White', 'Black', 'Asian', 'Arab', 'Any'], candidate_body_type: ['Slim', 'Athletic', 'Average', 'Heavyset', 'Any']});

export const checkValidValuesReviewSubmission = checkValidValues({status: ['pending', 'under_review', 'accepted', 'rejected']});

// Other Validators

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