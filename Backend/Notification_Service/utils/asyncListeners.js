import { Notification } from "../models/notification.js";
import { NotificationPreference } from "../models/notification_preference.js";
import {
  handleAuditionSubmission,
  handleCallbackEvents,
  handleEvaluationDone,
  handleInvitationEvents,
} from "../services/asyncListeners.js";
import {
  assertExchange,
  assertQueue,
  bindQueue,
  consumeMessages,
  EXCHANGES,
  QUEUES,
  ROUTING_KEYS,
} from "../utils/rabbitmq.js";

const handleUserCreated = async (content) => {
  try {
    await NotificationPreference.create(content.user_id, content.email);
  } catch (error) {
    console.error("Couldn't Create Notification Preference. \n ", {
      user_id: content.user_id,
      user_email: content.email,
    });
  }
};

const handleUserDeleted = async (content) => {
  try {
    await NotificationPreference.deleteByUserId(content.user_id);
    await Notification.deleteByUserId(content.user_id);
  } catch (error) {
    console.errror("Couldn't Delete User Data. \n ", { user_id: content.user_id });
  }
};

const handleUserEvents = async (routingKey, data) => {
  switch (routingKey) {
    case ROUTING_KEYS.USER_CREATED:
      await handleUserCreated(data);
      break;
    case ROUTING_KEYS.USER_DELETED:
      await handleUserDeleted(data);
      break;
  }
};

const executeAsyncListeners = () => {
  consumeMessages(QUEUES.INVITATION_EVENTS, handleInvitationEvents);
  consumeMessages(QUEUES.AUDITION_EVENTS, handleAuditionSubmission);
  consumeMessages(QUEUES.EVALUATION_EVENTS, handleEvaluationDone);
  consumeMessages(QUEUES.USER_EVENTS, handleUserEvents);
  consumeMessages(QUEUES.CALLBACK_EVENTS, handleCallbackEvents);
};

export const setupAsyncListeners = async () => {
  try {
    Object.entries(EXCHANGES).forEach(async ([event, exchange]) => {
      await assertExchange(exchange);
    });

    Object.entries(QUEUES).forEach(async ([event, queue]) => {
      await assertQueue(queue);
    });

    Object.entries(ROUTING_KEYS).forEach(async ([event, routingKey]) => {
      const groupName = routingKey.slice(0, routingKey.indexOf("."));

      if (groupName === 'evaluation') {
        await bindQueue(QUEUES.EVALUATION_EVENTS, EXCHANGES.EVALUATIONS, routingKey);
        return;
      }

      await bindQueue(
        `notification_${groupName}_events_queue`,
        `${groupName}s_exchange`,
        routingKey,
      );
    });

    executeAsyncListeners();
    console.log("Event subscribers setup complete");
  } catch (error) {
    console.error("Error setting up event subscribers:", error);
    throw error;
  }
};
