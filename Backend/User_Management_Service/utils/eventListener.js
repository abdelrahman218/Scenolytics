/**
 * Event Listener for User Management Service
 * Handles events from other services (e.g., user deletion)
 */

import {
  assertExchange,
  assertQueue,
  bindQueue,
  consumeMessages,
  EXCHANGES,
  QUEUES,
  ROUTING_KEYS
} from './rabbitmq.js';
import ActorProfile from '../models/actorProfile.js';
import DirectorProfile from '../models/directorProfile.js';

/**
 * Initialize event listeners for User Management Service
 */
export const initializeEventListeners = async () => {
  try {
    // Assert exchanges
    await assertExchange(EXCHANGES.USERS);

    // Assert user events queue
    await assertQueue(QUEUES.USER_EVENTS);

    // Bind queue to USER_DELETED event
    await bindQueue(QUEUES.USER_EVENTS, EXCHANGES.USERS, ROUTING_KEYS.USER_DELETED);

    // Start consuming USER_DELETED events
    await consumeMessages(QUEUES.USER_EVENTS, handleUserDeletedEvent);

    console.log('Event listeners initialized for User Management Service');
  } catch (error) {
    console.error('Failed to initialize event listeners:', error);
    throw error;
  }
};

/**
 * Handle USER_DELETED event
 * Clean up actor and director profiles when user is deleted
 */
const handleUserDeletedEvent = async (message) => {
  try {
    const { data } = message;
    const { user_id } = data;

    console.log(`Processing USER_DELETED event for user: ${user_id}`);

    // Delete actor profile if it exists
    try {
      const actorProfile = await ActorProfile.findByUserId(user_id);
      if (actorProfile) {
        await ActorProfile.delete(actorProfile.id);
        console.log(`Deleted actor profile for user: ${user_id}`);
      }
    } catch (error) {
      console.warn(`Failed to delete actor profile for user ${user_id}:`, error.message);
    }

    // Delete director profile if it exists
    try {
      const directorProfile = await DirectorProfile.findByUserId(user_id);
      if (directorProfile) {
        await DirectorProfile.delete(directorProfile.id);
        console.log(`Deleted director profile for user: ${user_id}`);
      }
    } catch (error) {
      console.warn(`Failed to delete director profile for user ${user_id}:`, error.message);
    }

    console.log(`Successfully cleaned up profiles for deleted user: ${user_id}`);
  } catch (error) {
    console.error('Error handling USER_DELETED event:', error);
    throw error;
  }
};
