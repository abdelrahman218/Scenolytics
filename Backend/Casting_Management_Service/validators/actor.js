import { checkRequiredFields, checkValidValues } from "./general";
import { AuditionSubmission } from "../models/audition_submission";

// Checking Required Fields for each endpoint

export const checkRequiredFieldsRespondToInvitation = checkRequiredFields(['status']);

//export const checkRequiredFieldsSubmitAuditionSubmission = checkRequiredFields(['media_id']);

// Checking Valid Values for each endpoint

export const checkValidValuesRespondToInvitation = checkValidValues({status: ['accepted', 'declined']});

// Other Validators

export const checkAuditionNotSubmitted = async(req, res, next) => {
    const submission = await AuditionSubmission.findByAuditionIdAndActorId(req.params.audition_id, req.user.id);
    if (submission) {
        return res.status(400).json({ message: 'Audition already submitted' });
    }
    next();
};