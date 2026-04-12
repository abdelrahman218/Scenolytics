import { Audition } from "../models/audition.js";
import { AuditionInvitation } from "../models/audition_invitation.js";
import { AuditionSubmission } from "../models/audition_submission.js";
import { EXCHANGES, publishMessage, ROUTING_KEYS } from "../utils/rabbitmq.js";
import { PutObjectCommand } from '@aws-sdk/client-s3'
import { getSignedUrl } from '@aws-sdk/s3-request-presigner'
import { s3 } from '../config/s3.js'

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

const generatePresignedUploadUrl = async(media_id) => {
    const key = `uploads/${media_id}.mp4`
  
    const url = await getSignedUrl(
      s3,
      new PutObjectCommand({
        Bucket: process.env.S3_BUCKET_VIDEOS,
        Key: key,
      })
    )
  
    // Rewrite internal Docker hostname → public localhost URL for browser access
    const internal = process.env.AWS_ENDPOINT_URL ?? '';
    const public_  = process.env.S3_PUBLIC_URL ?? internal;
  
    return url.replace(internal, public_)
}

export const submitAuditionSubmission = async (req, res, next) => {
    try {
        const submission = await AuditionSubmission.create({
            audition_id: req.params.audition_id,
            actor_id: req.user.user_id,
        });

        const uploadURL = await generatePresignedUploadUrl(submission.media_id);
        console.log(uploadURL)

        publishMessage(EXCHANGES.AUDITIONS, ROUTING_KEYS.AUDITION_SUBMITTED, submission);
        return res.status(201).json({message: 'Submission metadata saved successfully', submission, uploadURL});
    } catch (error) {
        next(error);
    }
};