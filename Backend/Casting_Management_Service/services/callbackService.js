import { v4 as uuidv4 } from 'uuid';
import { Callback, CallbackSubmission } from '../models/callback.js';
import { identityProviderService, userManagementService, mediaProcessingService, notificationService } from '../utils/serviceClient.js';

export const sendCallback = async (audition_id, director_id, actor_id, scriptContent, scriptUrl) => {
  try {
    // Validate director and actor exist
    const directorExists = await identityProviderService.checkUserExists(director_id);
    if (!directorExists) {
      throw new Error('Director not found in Identity Provider');
    }

    const actorExists = await identityProviderService.checkUserExists(actor_id);
    if (!actorExists) {
      throw new Error('Actor not found in Identity Provider');
    }

    const callbackId = uuidv4();
    await Callback.create({
      id: callbackId,
      audition_id,
      director_id,
      actor_id,
      callback_status: 'sent',
      script_content: scriptContent,
      script_url: scriptUrl
    });

    // Send notification to actor
    try {
      await notificationService.sendNotification(
        actor_id,
        'callback_received',
        'New Callback Request',
        `You have received a new callback request for audition ${audition_id}`,
        callbackId
      );
    } catch (notifError) {
      console.warn('Failed to send notification:', notifError.message);
    }

    return {
      id: callbackId,
      audition_id,
      director_id,
      actor_id,
      callback_status: 'sent'
    };
  } catch (error) {
    throw new Error(`Failed to send callback: ${error.message}`);
  }
};

export const getCallback = async (callback_id) => {
  try {
    const callback = await Callback.findById(callback_id);
    if (!callback) throw new Error('Callback not found');
    return callback;
  } catch (error) {
    throw new Error(`Failed to retrieve callback: ${error.message}`);
  }
};

export const getActorCallbacks = async (actor_id) => {
  try {
    const callbacks = await Callback.findByActorId(actor_id);
    return callbacks;
  } catch (error) {
    throw new Error(`Failed to retrieve actor callbacks: ${error.message}`);
  }
};

export const respondToCallback = async (callback_id, status) => {
  try {
    await Callback.updateStatus(callback_id, status, new Date());
    return await Callback.findById(callback_id);
  } catch (error) {
    throw new Error(`Failed to respond to callback: ${error.message}`);
  }
};

export const submitCallbackVideo = async (callback_id, media_id) => {
  try {
    // Validate media exists
    const media = await mediaProcessingService.getMedia(media_id);
    if (!media) {
      throw new Error('Media not found in Media Processing Service');
    }

    const submissionId = uuidv4();
    await CallbackSubmission.create({
      id: submissionId,
      callback_id,
      media_id,
      submission_status: 'pending'
    });

    // Get callback details to notify director
    const callback = await Callback.findById(callback_id);
    if (callback) {
      try {
        await notificationService.sendNotification(
          callback.director_id,
          'submission_received',
          'Callback Submission Received',
          `Actor has submitted a callback video for audition ${callback.audition_id}`,
          submissionId
        );
      } catch (notifError) {
        console.warn('Failed to send notification:', notifError.message);
      }
    }

    return {
      id: submissionId,
      callback_id,
      media_id,
      submission_status: 'pending'
    };
  } catch (error) {
    throw new Error(`Failed to submit callback video: ${error.message}`);
  }
};

export const getCallbackSubmissions = async (callback_id) => {
  try {
    const submissions = await CallbackSubmission.findByCallbackId(callback_id);
    return submissions;
  } catch (error) {
    throw new Error(`Failed to retrieve callback submissions: ${error.message}`);
  }
};

export const reviewCallbackSubmission = async (submission_id, status, directorNotes) => {
  try {
    await CallbackSubmission.updateStatus(submission_id, status, directorNotes);
    const submission = await CallbackSubmission.findById(submission_id);
    return submission;
  } catch (error) {
    throw new Error(`Failed to review callback submission: ${error.message}`);
  }
};
