/**
 * Service for publishing callback/casting-related events to RabbitMQ
 */

import { publishMessage, EXCHANGES, ROUTING_KEYS } from '../utils/rabbitmq.js';

export const publishCallbackCreated = async (callbackData) => {
  try {
    await publishMessage(
      EXCHANGES.CALLBACKS,
      ROUTING_KEYS.CALLBACK_CREATED,
      {
        eventType: 'CALLBACK_CREATED',
        timestamp: new Date(),
        data: callbackData
      }
    );
  } catch (error) {
    console.error('Error publishing callback created event:', error);
    throw error;
  }
};

export const publishCallbackUpdated = async (callbackData) => {
  try {
    await publishMessage(
      EXCHANGES.CALLBACKS,
      ROUTING_KEYS.CALLBACK_UPDATED,
      {
        eventType: 'CALLBACK_UPDATED',
        timestamp: new Date(),
        data: callbackData
      }
    );
  } catch (error) {
    console.error('Error publishing callback updated event:', error);
    throw error;
  }
};
