import Actor from "../models/actor.js";
import { Audition } from "../models/audition.js";
import { AuditionInvitation } from "../models/audition_invitation.js";
import { AuditionSubmission } from "../models/audition_submission.js";
import { Callback } from "../models/callback.js";
import { GoogleCalendarCredentials } from "../models/google_calender_credentials.js";
import { assertExchange, assertQueue, bindQueue, consumeMessages, EXCHANGES, QUEUES, ROUTING_KEYS } from "./rabbitmq.js";

const handleUserEvents = async (routingKey, data) => {
  try {
    if (routingKey === ROUTING_KEYS.USER_CREATED){
      if(data.role !== 'actor'){
        return;
      }
      await Actor.Create(data.user_id, data.email);
    }else if (routingKey === ROUTING_KEYS.USER_DELETED){
      await Actor.Delete(data.user_id);
      await Audition.deleteByDirectorId(data.user_id);
      await AuditionSubmission.deleteByActorId(data.user_id);
      await AuditionInvitation.deleteByActorId(data.user_id);
      await Callback.deleteByActorId(data.user_id);
      await GoogleCalendarCredentials.deleteByDirectorId(data.user_id);
    }
  } catch (error) {
    console.error("Couldn\'t create/delete user data. \n " + data);
  }
};

const handleEvaluationDone = async (routingKey, data) => {
  try {
    await AuditionSubmission.updateStatus(data.submission_id, 'under_review', null)
  } catch (error) {
    console.error("Couldn\'t Update Submission Status. \n" + data);
  }
};

const executeAsyncListeners = () => {
  consumeMessages(QUEUES.USER_EVENTS, handleUserEvents);
  consumeMessages(QUEUES.EVALUATION_EVENTS, handleEvaluationDone);
};

export const setupAsyncListeners = () => {
  Object.entries(EXCHANGES).forEach(async ([event, exchange]) => {
    await assertExchange(exchange);
  });
  
  Object.entries(QUEUES).forEach(async ([event, queue]) => {
    await assertQueue(queue);
  });

  Object.entries(ROUTING_KEYS).forEach(async ([event, routingKey]) => {
    const groupName = routingKey.slice(0, routingKey.indexOf('.'));

    if (groupName === 'evaluation') {
      await bindQueue(QUEUES.EVALUATION_EVENTS, EXCHANGES.EVALUATIONS, routingKey);
      return;
    }

    await bindQueue(`casting_management_${groupName}_events_queue`, `${groupName}s_exchange`, routingKey);
  });

  executeAsyncListeners();
  console.log("Event subscribers setup complete");
}
