/**
 * Service for subscribing to events from other services via RabbitMQ
 * and sending notifications
 */

import { assertExchange, assertQueue, bindQueue, consumeMessages, EXCHANGES, QUEUES, ROUTING_KEYS } from '../utils/rabbitmq.js';

/**
 * Setup all event subscribers for the Notification Service
 */
export const setupEventSubscribers = async () => {
  try {
    // Assert exchanges
    await Promise.all([
      assertExchange(EXCHANGES.USERS),
      assertExchange(EXCHANGES.AUDITIONS),
      assertExchange(EXCHANGES.VIDEOS),
      assertExchange(EXCHANGES.EVALUATIONS),
      assertExchange(EXCHANGES.CALLBACKS)
    ]);

    // Create notification queue
    await assertQueue(QUEUES.NOTIFICATION_QUEUE);

    // Bind queue to exchanges with specific routing keys
    await Promise.all([
      bindQueue(QUEUES.NOTIFICATION_QUEUE, EXCHANGES.USERS, ROUTING_KEYS.USER_CREATED),
      bindQueue(QUEUES.NOTIFICATION_QUEUE, EXCHANGES.AUDITIONS, ROUTING_KEYS.AUDITION_COMPLETED),
      bindQueue(QUEUES.NOTIFICATION_QUEUE, EXCHANGES.EVALUATIONS, ROUTING_KEYS.EVALUATION_COMPLETED),
      bindQueue(QUEUES.NOTIFICATION_QUEUE, EXCHANGES.CALLBACKS, ROUTING_KEYS.CALLBACK_CREATED),
      bindQueue(QUEUES.NOTIFICATION_QUEUE, EXCHANGES.VIDEOS, ROUTING_KEYS.VIDEO_PROCESSING_COMPLETED)
    ]);

    // Start consuming messages
    await consumeMessages(QUEUES.NOTIFICATION_QUEUE, handleNotificationEvent);

    console.log('Event subscribers setup complete');
  } catch (error) {
    console.error('Error setting up event subscribers:', error);
    throw error;
  }
};

/**
 * Handle incoming notification events
 */
export const handleNotificationEvent = async (event) => {
  try {
    console.log(`Received event: ${event.eventType}`, event.data);

    switch (event.eventType) {
      case 'USER_CREATED':
        await handleUserCreated(event.data);
        break;

      case 'AUDITION_COMPLETED':
        await handleAuditionCompleted(event.data);
        break;

      case 'EVALUATION_COMPLETED':
        await handleEvaluationCompleted(event.data);
        break;

      case 'CALLBACK_CREATED':
        await handleCallbackCreated(event.data);
        break;

      case 'VIDEO_PROCESSING_COMPLETED':
        await handleVideoProcessingCompleted(event.data);
        break;

      default:
        console.warn(`Unknown event type: ${event.eventType}`);
    }
  } catch (error) {
    console.error('Error handling notification event:', error);
    throw error;
  }
};

/**
 * Handle user created event
 */
export const handleUserCreated = async (userData) => {
  try {
    console.log('Sending welcome notification to new user:', userData.id);
    
    // TODO: Send welcome email/notification
    // const notification = {
    //   user_id: userData.id,
    //   type: 'email',
    //   subject: 'Welcome to Scenolytics',
    //   template: 'welcome_email',
    //   data: userData
    // };
    // await sendNotification(notification);
  } catch (error) {
    console.error('Error sending user created notification:', error);
  }
};

/**
 * Handle audition completed event
 */
export const handleAuditionCompleted = async (sessionData) => {
  try {
    console.log('Sending audition completion notification:', sessionData.id);
    
    // TODO: Send audition completion email
    // const notification = {
    //   user_id: sessionData.actor_id,
    //   type: 'email',
    //   subject: 'Your Audition Session Completed',
    //   template: 'audition_completed',
    //   data: sessionData
    // };
    // await sendNotification(notification);
  } catch (error) {
    console.error('Error sending audition completed notification:', error);
  }
};

/**
 * Handle evaluation completed event
 */
export const handleEvaluationCompleted = async (evaluationData) => {
  try {
    console.log('Sending evaluation completed notification:', evaluationData.id);
    
    // TODO: Send evaluation results email
    // const notification = {
    //   user_id: evaluationData.actor_id,
    //   type: 'email',
    //   subject: 'Your Evaluation Results Are Ready',
    //   template: 'evaluation_results',
    //   data: evaluationData
    // };
    // await sendNotification(notification);
  } catch (error) {
    console.error('Error sending evaluation completed notification:', error);
  }
};

/**
 * Handle callback created event
 */
export const handleCallbackCreated = async (callbackData) => {
  try {
    console.log('Sending callback notification:', callbackData.id);
    
    // TODO: Send callback email/notification
    // const notification = {
    //   user_id: callbackData.actor_id,
    //   type: 'email',
    //   subject: 'You Have a Callback',
    //   template: 'callback_notification',
    //   data: callbackData
    // };
    // await sendNotification(notification);
  } catch (error) {
    console.error('Error sending callback notification:', error);
  }
};

/**
 * Handle video processing completed event
 */
export const handleVideoProcessingCompleted = async (videoData) => {
  try {
    console.log('Sending video processing completed notification:', videoData.id);
    
    // TODO: Send video processing completion notification
    // const notification = {
    //   user_id: videoData.actor_id,
    //   type: 'email',
    //   subject: 'Your Video Has Been Processed',
    //   template: 'video_processed',
    //   data: videoData
    // };
    // await sendNotification(notification);
  } catch (error) {
    console.error('Error sending video processing completed notification:', error);
  }
};
