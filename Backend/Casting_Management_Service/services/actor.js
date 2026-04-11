import { Audition } from "../models/audition.js";
import { AuditionInvitation } from "../models/audition_invitation.js";
import { AuditionSubmission } from "../models/audition_submission.js";
import { EXCHANGES, publishMessage, ROUTING_KEYS } from "../utils/rabbitmq.js";

export const respondToInvitation = async (req, res, next) => {
    try {
        const invitation = await AuditionInvitation.updateStatus(req.params.invitation_id, req.body.status);
        
        if (!invitation){
            return res.status(404).json({message: 'invitation not found'});
        }
    
        const director_id = (await Audition.findById(invitation.audition_id)).director_id;
        
        publishMessage(EXCHANGES.INVITATIONS, ROUTING_KEYS.INVITATION_UPDATED, { ...invitation, director_id });
        return res.status(200).json({message: `Invitation ${req.body.status}ed successfully`});
    } catch (error) {
        next(error);
    }
};

export const getActorPendingInvitations = async (req, res, next) => {
    try {
        const invitations = await AuditionInvitation.findByActorIdAndStatus(req.user.user_id, 'pending');
        return res.status(200).json(invitations);
    } catch (error) {
        next(error);
    }
};

export const getActorSubmissions = async (req, res, next) => {
    try {
        const submissions = await AuditionSubmission.findByActorId(req.user.user_id);
        return res.status(200).json(submissions);
    } catch (error) {
        next(error);
    }
};

export const submitAuditionSubmission = async (req, res, next) => {
    try {
        const submission = await AuditionSubmission.create({
            audition_id: req.params.audition_id,
            actor_id: req.user.user_id,
            media_id: req.body.media_id,
        });

        publishMessage(EXCHANGES.AUDITIONS, ROUTING_KEYS.AUDITION_SUBMITTED, submission);
        return res.status(201).json({message: 'Submission metadata saved successfully', submission});
    } catch (error) {
        next(error);
    }
};