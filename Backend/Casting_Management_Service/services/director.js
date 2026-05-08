import { Audition } from "../models/audition.js";
import { AuditionInvitation } from "../models/audition_invitation.js";
import { AuditionSubmission } from "../models/audition_submission.js";
import { Callback } from "../models/callback.js";
import { Sentence } from "../models/sentence.js"
import { EXCHANGES, publishMessage, ROUTING_KEYS } from "../utils/rabbitmq.js";

export const createAudition = async (req, res, next) => {
    try {
        let audition = await Audition.create(req.body, req.user.user_id);
        const script = [];

        if (req.body.script){
            let order = 1;
            for (const senctence of req.body.script) {
                let savedSentence = await Sentence.create({...senctence, audition_id: audition.id, sentence_order: order++});
                script.push(savedSentence);
            }
        }

        audition = { ...audition, script };
        publishMessage(EXCHANGES.AUDITIONS, ROUTING_KEYS.AUDITION_CREATED, audition);
        return res.status(201).json({message: 'Audition created successfully', audition});
    } catch (error) {
        next(error);
    }
};

export const getAllDirectorAuditions = async (req, res, next) => {
    try {
        const auditions = await Audition.findByDirectorId(req.user.user_id);
        return res.status(200).json(auditions);
    } catch (error) {
        next(error);
    }
};

export const updateAudition = async (req, res, next) => {
    try {
        const audition_id = req.params.audition_id;
        let audition = await Audition.update(audition_id, req.body, req.user.user_id);
        const script = [];
        if(req.body.script) {
            await Sentence.deleteByAuditionId(audition_id);
    
            let order = 1;
            for (const senctence of req.body.script) {
                let savedSentence = await Sentence.create({...senctence, audition_id: audition.id, sentence_order: order});
                order = order + 1;
                script.push(savedSentence);
            }
        }
        audition = { ...audition, script };

        publishMessage(EXCHANGES.AUDITIONS, ROUTING_KEYS.AUDITION_UPDATED, audition);
        return res.status(200).json({message: 'Audition updated successfully', audition});
    } catch (error) {
        next(error);
    }
};

export const deleteAudition = async (req, res, next) => {
    try {
        const audition = await Audition.delete(req.params.audition_id);
        publishMessage(EXCHANGES.AUDITIONS, ROUTING_KEYS.AUDITION_DELETED, audition);
        return res.status(200).json({message: 'Audition deleted successfully'});
    } catch (error) {
        next(error);
    }
};

export const inviteActorsToAudition = async (req, res, next) => {
    try {
        const invitations = [];
        for (const actor_id of req.body.actor_ids) {
            let invitation = await AuditionInvitation.create({
                audition_id: req.params.audition_id,
                actor_id: actor_id
            });

            invitations.push(invitation);
            publishMessage(EXCHANGES.INVITATIONS, ROUTING_KEYS.INVITATION_CREATED, invitation);
        }

        return res.status(201).json({message: 'Actors invited successfully', invitations});
    } catch (error) {
        next(error);
    }
};

export const getDirectorPendingInvitations = async (req, res, next) => {
    try {
        const invitations = await AuditionInvitation.findByDirectorIdAndStatus(req.user.user_id, 'pending');
        return res.status(200).json(invitations);
    } catch (error) {
        next(error);
    }
};

export const getAuditionPendingInvitations = async (req, res, next) => {
    try {
        const invitations = await AuditionInvitation.findByAuditionIdAndStatus(req.params.audition_id, 'pending');
        return res.status(200).json(invitations);
    } catch (error) {
        next(error);
    }
};

export const getActorsForAudition = async (req, res, next) => {
    try {
        const data = await AuditionInvitation.findByAuditionIdAndStatus(req.params.audition_id, 'accepted');
        data.push(await AuditionSubmission.findByAuditionId(req.params.audition_id));
        const actor_ids = data.map((actor) => actor.actor_id);
        return res.status(200).json(actor_ids);
    } catch (error) {
        next(error);
    }
};

export const getAuditionSubmissions = async (req, res, next) => {
    try {
        const submissions = await AuditionSubmission.findByAuditionId(req.params.audition_id);
        return res.status(200).json(submissions);
    } catch (error) {
        next(error);
    }
};

export const reviewSubmission = async (req, res, next) => {
    try {
        const submission = await AuditionSubmission.updateStatus(req.params.submission_id, req.body.status, req.body.director_notes);
        
        if (submission.submission_status == 'accepted') {

            const link = '';
            const callback = await Callback.create({
                audition_id: submission.audition_id,
                actor_id: submission.actor_id,
                audition_submission_id: submission.id,
                callback_datetime: req.body.callback_datetime || null,
                link,
            });
            publishMessage(EXCHANGES.CALLBACKS, ROUTING_KEYS.CALLBACK_CREATED, callback);
        }

        publishMessage(EXCHANGES.AUDITIONS, ROUTING_KEYS.AUDITION_REVIEWED, submission);
        return res.status(200).json(submission);
    } catch (error) {
        next(error);
    }
};

export const getAuditionCallbacks = async (req, res, next) => {
    try {
        const callbacks = await Callback.findByAuditionId(req.params.audition_id);
        return res.status(200).json(callbacks);
    } catch (error) {
        next(error);
    }
};

export const rescheduleCallback = async (req, res, next) => {
    try {
        const updatedData = { callback_datetime: req.body.callback_datetime };
        
        const callback = await Callback.update(req.params.callback_id, updatedData);
        publishMessage(EXCHANGES.CALLBACKS, ROUTING_KEYS.CALLBACK_UPDATED, callback);
        return res.status(200).json(callback);
    } catch (error) {
        next(error);
    }
};

export const createNewCallbackMeeting = async (req, res, next) => {
    try {
        const link = '';
        
        const callback = await Callback.update(req.params.callback_id, { link });
        publishMessage(EXCHANGES.CALLBACKS, ROUTING_KEYS.CALLBACK_UPDATED, callback);
        return res.status(200).json({message: 'New Callback link created successfully', link});
    } catch (error) {
        next(error);
    }
};

export const reviewCallback = async (req, res, next) => {
    try {
        const updatedData = { callback_status: req.body.status };
        
        if (req.body.director_notes){
            updatedData.director_notes = req.body.director_notes;
        }

        const callback = await Callback.update(req.params.callback_id, updatedData);
        publishMessage(EXCHANGES.CALLBACKS, ROUTING_KEYS.CALLBACK_UPDATED, callback);
        return res.status(200).json(callback);
    } catch (error) {
        next(error);
    }
};