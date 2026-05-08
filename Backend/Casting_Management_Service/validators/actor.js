import { checkRequiredFields, checkValidValues } from "./general.js";
import { AuditionSubmission } from "../models/audition_submission.js";
import { AuditionInvitation } from "../models/audition_invitation.js";

// Check Authorization

export const checkActorOwnershipOfInvitation = async(req, res, next) => {
    const invitation = await AuditionInvitation.findById(req.params.invitation_id);

    if (invitation.actor_id !== req.user.user_id) {
        return res.status(403).json({ message: 'You are not authorized to perform this action' });
    }
    next();
};

// Checking Required Fields for each endpoint

export const checkRequiredFieldsRespondToInvitation = checkRequiredFields(['status']);

// Checking Valid Values for each endpoint

export const checkValidValuesRespondToInvitation = checkValidValues({status: ['accepted', 'declined']});

// Other Validators

export const checkAuditionNotSubmitted = async(req, res, next) => {
    const submission = await AuditionSubmission.findByAuditionIdAndActorId(req.params.audition_id, req.user.user_id);
    if (submission) {
        return res.status(400).json({ message: 'Audition already submitted' });
    }
    next();
};