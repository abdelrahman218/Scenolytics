/**
 * Service for publishing audition-related events to RabbitMQ
 */

import { publishMessage, EXCHANGES, ROUTING_KEYS } from '../utils/rabbitmq.js';

export const publishAuditionStarted = async (sessionData) => {
  try {
    await publishMessage(
      EXCHANGES.AUDITIONS,
      ROUTING_KEYS.AUDITION_STARTED,
      {
        eventType: 'AUDITION_STARTED',
        timestamp: new Date(),
        data: sessionData
      }
    );
  } catch (error) {
    console.error('Error publishing audition started event:', error);
    throw error;
  }
};

export const publishAuditionCompleted = async (sessionData) => {
  try {
    await publishMessage(
      EXCHANGES.AUDITIONS,
      ROUTING_KEYS.AUDITION_COMPLETED,
      {
        eventType: 'AUDITION_COMPLETED',
        timestamp: new Date(),
        data: sessionData
      }
    );
  } catch (error) {
    console.error('Error publishing audition completed event:', error);
    throw error;
  }
};
