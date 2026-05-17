import { createActorProfile } from "../services/actorService.js";
import { createDirectorProfile } from "../services/directorService.js";
import { assertExchange, assertQueue, bindQueue, consumeMessages, EXCHANGES, QUEUES, ROUTING_KEYS } from "./rabbitmq.js";

const handleUserCreated = async (routingKey, data) => {
  try {
    const role = data.role;

    if(role == 'actor'){
      createActorProfile(data.user_id, data);
    }

    if(role == 'director'){
      createDirectorProfile(data.user_id, data);
    }
  } catch (error) {
    console.error("Coulding create user profile. \n " + data);
  }
};

const executeAsyncListeners = () => {
  consumeMessages(QUEUES.USER_EVENTS, handleUserCreated);
};

export const setupAsyncListeners = async () => {

  await assertExchange(EXCHANGES.USERS)
  await assertQueue(QUEUES.USER_EVENTS);
  await bindQueue(QUEUES.USER_EVENTS, EXCHANGES.USERS, ROUTING_KEYS.USER_CREATED);

  executeAsyncListeners();
}