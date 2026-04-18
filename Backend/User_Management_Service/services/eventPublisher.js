/**
 * Service for publishing user-related events to RabbitMQ
 */

import { publishMessage, EXCHANGES, ROUTING_KEYS } from '../utils/rabbitmq.js';

export const publishUserCreated = async (userData) => {
  try {
    await publishMessage(
      EXCHANGES.USERS,
      ROUTING_KEYS.USER_CREATED,
      {
        eventType: 'USER_CREATED',
        timestamp: new Date(),
        data: userData
      }
    );
  } catch (error) {
    console.error('Error publishing user created event:', error);
    throw error;
  }
};

export const publishUserUpdated = async (userData) => {
  try {
    await publishMessage(
      EXCHANGES.USERS,
      ROUTING_KEYS.USER_UPDATED,
      {
        eventType: 'USER_UPDATED',
        timestamp: new Date(),
        data: userData
      }
    );
  } catch (error) {
    console.error('Error publishing user updated event:', error);
    throw error;
  }
};

export const publishUserDeleted = async (userId) => {
  try {
    await publishMessage(
      EXCHANGES.USERS,
      ROUTING_KEYS.USER_DELETED,
      {
        eventType: 'USER_DELETED',
        timestamp: new Date(),
        data: { userId }
      }
    );
  } catch (error) {
    console.error('Error publishing user deleted event:', error);
    throw error;
  }
};
