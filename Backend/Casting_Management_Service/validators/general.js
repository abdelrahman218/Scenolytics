import { Audition } from "../models/audition.js";
import { AuditionInvitation } from "../models/audition_invitation.js";

export const checkRequiredFields = (fields) => {
    return (req, res, next) => {
        const missingFields = fields.filter(field => !req.body[field]);
        if (missingFields.length > 0) {
            return res.status(400).json({ message: `Missing required fields: ${missingFields.join(', ')}` });
        }
        next();
    };
};

export const checkValidValues = (fieldsValues) => {
    return (req, res, next) => {
        Object.entries(fieldsValues).forEach(([field, values]) => {
            if (!values.includes(req.body[field]) && req.body[field]) {
                return res.status(400).json({ message: `Invalid value for ${field}: ${req.body[field]}` });
            }
        });
        next();
    };
};

export const checkInvitationIsPending = async(req, res, next) => {
    const invitation = await AuditionInvitation.findById(req.params.invitation_id);
    if (invitation.invitation_status !== 'pending') {
        return res.status(400).json({ message: 'Invitation is not pending' });
    }
    next();
};

export const checkAuditionExists = async(req, res, next) => {
    const audition = await Audition.findById(req.params.audition_id);
    if (!audition) {
        return res.status(404).json({ message: 'Audition not found' });
    }
    next();
};

export const checkRequiredFieldsGoogleConnectCallback = checkRequiredFields(['code', 'state']);