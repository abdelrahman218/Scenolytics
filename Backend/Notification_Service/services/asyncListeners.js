import { Notification } from '../models/notification.js'
import { ROUTING_KEYS } from '../utils/rabbitmq.js';
import { sendEmailNotification } from './emailService.js';
import { sendActiveInAppNotification } from './webSocketService.js';

const handleNewInvitation = async(content) => {
  const notification = await Notification.create({user_id: content.actor_id,
    notification_type: 'Invitation Notification',
    title: '🎭 You\'re Invited to a New Audition',
    message: 'You have been invited by a director to audition for a new role. Log in to your Scenolytics dashboard to view the details and submit your video/audio.',
    related_id: content.audition_id
  });

  sendActiveInAppNotification(notification);
  sendEmailNotification(notification);
};

const handleInvitationResponse = async(content) => {
  if(content.invitation_status != 'accepted') 
    return;

  const notification = await Notification.create({
    user_id: content.director_id,
    notification_type: 'Invitation Notification',
    title: '✅ Invitation Accepted',
    message: 'Great news! An actor has accepted your invitation to audition. You will be notified once their submission is ready.',
    related_id: content.actor_id
  });

  sendActiveInAppNotification(notification);
  sendEmailNotification(notification);
};

export const handleInvitationEvents = async (routingKey, data) => {
  switch(routingKey){
    case ROUTING_KEYS.INVITATION_CREATED:
      handleNewInvitation(data);
      break;
    case ROUTING_KEYS.INVITATION_UPDATED:
      handleInvitationResponse(data);
      break;
  }
}

export const handleAuditionSubmission = async (routingKey, data) => {
  let title;
  let message;
  switch (data.submission_status){
    case 'accepted':
      title = '🎉 Congratulations! You\'ve Been Selected';
      message = 'Congratulations! The director was impressed with your performance and has accepted your audition submission. Please check your dashboard for the next steps.';
      break;    
    case 'rejected':
      title = 'Update on your Recent Audition';
      message = 'Thank you for applying and sharing your talent with us. The director has decided to move forward with other candidates at this time. We encourage you to keep applying for future roles on Scenolytics!';
      break;
    default:
      return;
  }

  const notification = await Notification.create({
    user_id: data.actor_id,
    notification_type: 'Submission Notification',
    title,
    message,
    related_id: data.submission_id
  });

  sendActiveInAppNotification(notification);
  sendEmailNotification(notification);
};

export const handleEvaluationDone = async (routingKey, data) => {
  const notification = await Notification.create({
    user_id: data.director_id,
    notification_type: 'Submission Notification',
    title: '🤖 AI Evaluation Complete',
    message: 'The Scenolytics AI Module has finished evaluating a new candidate\'s submission. The results are now available for your review on the dashboard.',
    related_id: data.submission_id
  });

  sendActiveInAppNotification(notification);
  sendEmailNotification(notification);
};
