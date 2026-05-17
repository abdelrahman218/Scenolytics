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

  } catch (error) {
    console.error('[EVENT_LISTENER] Failed to initialize event listeners:', error);
    throw error;
  }
};

/**
 * Handle USER_DELETED event
 * Clean up actor and director profiles when user is deleted
 */
const handleUserDeletedEvent = async (message) => {
  try {
    const { user_id } = message;

    let deleted = false;

    // Delete actor profile if it exists
    try {
      const actorProfile = await ActorProfile.findByUserId(user_id);
      if (actorProfile) {
        await ActorProfile.delete(actorProfile.id);
        deleted = true;
      }
    } catch (error) {
      console.error(`[USER_DELETED] Failed to delete actor profile for user ${user_id}:`, error);
    }

    // Delete director profile if it exists
    try {
      const directorProfile = await DirectorProfile.findByUserId(user_id);
      if (directorProfile) {
        await DirectorProfile.delete(directorProfile.id);
        deleted = true;
      }
    } catch (error) {
      console.error(`[USER_DELETED] Failed to delete director profile for user ${user_id}:`, error);
    }
  } catch (error) {
    console.error('[USER_DELETED] Error processing event:', error);
  }
};
const handleUserRegisteredEvent = async (message) => {
  try {
    const { user_id } = message;
    // Optionally, create default profiles for new users
    try {
      await ActorProfile.create({ user_id, name: 'New Actor' });
    } catch (error) {
      console.error(`[USER_REGISTERED] Failed to create actor profile for user ${user_id}:`, error);
    }
    try {
      await DirectorProfile.create({ user_id, name: 'New Director' });
    } catch (error) {
      console.error(`[USER_REGISTERED] Failed to create director profile for user ${user_id}:`, error);
    }
  } catch (error) {
    console.error('[USER_REGISTERED] Error processing event:', error);
  }
};
