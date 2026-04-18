import { Notification } from '../models/notification.js'
import { ROUTING_KEYS } from '../utils/rabbitmq.js';
import { sendEmailNotification } from './emailService.js';
import { sendActiveInAppNotification } from './webSocketService.js';

const handleNewInvitation = async(content) => {
  const notification = await Notification.create({user_id: content.actor_id,
    notification_type: 'Invitation Notification',
    title: 'Audition Invitation',
    message: 'You have been invited to an audition',
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
    title: 'Audition Invitation Response',
    message: 'Actor has accepted invite',
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
  let message;
  switch (data.submission_status){
    case 'accepted':
      message = 'Congratulation!!\nYou have been acccepted in audition';
      break;    
    case 'rejected':
      message = 'Unfortunately, The director have decided to move on with other candidates\n Thank you for your efforts to apply for this audition';
      break;
    default:
      return;
  }

  const notification = await Notification.create({
    user_id: data.actor_id,
    notification_type: 'Submission Notification',
    title: 'Update on your submission',
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
    title: 'Pending Submissions Waiting',
    message: 'AI Module have finished evaluation for a candidate',
    related_id: data.submission_id
  });

  sendActiveInAppNotification(notification);
  sendEmailNotification(notification);
};
