import { Audition } from "../models/audition";
import { AuditionInvitation } from "../models/audition_invitation";
import { AuditionSubmission } from "../models/audition_submission";

export const getActorAudition = async (req, res, next) => {
    try {
        let audition = await Audition.findById(req.params.audition_id);
        return res.status(200).json(audition);
    } catch (error) {
        next(error);
    }
};

export const respondToInvitation = async (req, res, next) => {
    try {
        await AuditionInvitation.updateStatus(req.params.invitation_id, req.body.status);
        const updatedInvitation = await AuditionInvitation.findById(req.params.invitation_id);
        return res.status(200).json(updatedInvitation);
    } catch (error) {
        next(error);
    }
};

export const getActorInvitations = async (req, res, next) => {
    try {
        const invitations = await AuditionInvitation.findByActorId(req.user.user_id);
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
        return res.status(201).json(submission);
    } catch (error) {
        next(error);
    }
};