import { createActorProfile } from "../services/actorService.js";
import { createDirectorProfile } from "../services/directorService.js";
import { deleteActorProfile} from "../services/actorService.js";
import { deleteDirectorProfile } from "../services/directorService.js";
import { assertExchange, assertQueue, bindQueue, consumeMessages, EXCHANGES, QUEUES, ROUTING_KEYS } from "./rabbitmq.js";

const handleUserEvents = async (routingKey, data) => {
  try {
    if (routingKey === ROUTING_KEYS.USER_CREATED) {
      const role = data.role;
      if (role === 'actor') await createActorProfile(data.user_id, data);
      if (role === 'director') await createDirectorProfile(data.user_id, data);
    }

    if (routingKey === ROUTING_KEYS.USER_DELETED) {
      const user_id = data.user_id;
      const role = data.role;
      if (role === 'actor') await deleteActorProfileByUserId(user_id);
      if (role === 'director') await deleteDirectorProfileByUserId(user_id);
    }
  } catch (error) {
    console.error('[USER_EVENTS] Error processing event:', error);
  }
};

const executeAsyncListeners = () => {
  consumeMessages(QUEUES.USER_EVENTS, handleUserEvents);
};

export const setupAsyncListeners = async () => {
  await assertExchange(EXCHANGES.USERS)
  await assertQueue(QUEUES.USER_EVENTS);
  await bindQueue(QUEUES.USER_EVENTS, EXCHANGES.USERS, ROUTING_KEYS.USER_CREATED);
  await bindQueue(QUEUES.USER_EVENTS, EXCHANGES.USERS, ROUTING_KEYS.USER_DELETED);

  executeAsyncListeners();
}