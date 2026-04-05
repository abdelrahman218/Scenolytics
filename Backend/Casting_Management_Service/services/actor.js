import { Audition } from "../models/audition";
import { AuditionInvitation } from "../models/audition_invitation";
import { AuditionSubmission } from "../models/audition_submission";
import { Sentence } from "../models/sentence"
import { EXCHANGES, publishMessage, ROUTING_KEYS } from "../utils/rabbitmq";

export const getActorAudition = async (req, res, next) => {
    try {
        const audition_id = req.params.audition_id;
        let audition = await Audition.findById(audition_id);

        if (!audition){
            return res.status(404).json({message: 'audition not found'});
        }

        const script = await Sentence.findByAuditionId(audition_id);
        audition = {...audition, script };
        return res.status(200).json({audition});
    } catch (error) {
        next(error);
    }
};

export const respondToInvitation = async (req, res, next) => {
    try {
        const invitation = await AuditionInvitation.updateStatus(req.params.invitation_id, req.body.status);
        
        if (!invitation){
            return res.status(404).json({message: 'invitation not found'});
        }
    
        publishMessage(EXCHANGES.INVITATIONS, ROUTING_KEYS.INVITATION_UPDATED, invitation);
        
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
            media_id: req.body.media_id,
        });

        publishMessage(EXCHANGES.AUDITIONS, ROUTING_KEYS.AUDITION_SUBMITTED, submission);
        return res.status(201).json({message: 'Submission metadata saved successfully', submission});
    } catch (error) {
        next(error);
    }
};