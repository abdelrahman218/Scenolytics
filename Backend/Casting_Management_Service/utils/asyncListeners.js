import { Audition } from "../models/audition.js";
import { AuditionInvitation } from "../models/audition_invitation.js";
import { AuditionSubmission } from "../models/audition_submission.js";
import { assertExchange, assertQueue, bindQueue, consumeMessages, EXCHANGES, QUEUES, ROUTING_KEYS } from "./rabbitmq.js";

const handleUserDeleted = async (routingKey, data) => {
  try {
    await Audition.deleteByDirectorId(data.user_id);
    await AuditionSubmission.deleteByActorId(data.user_id);
    await AuditionInvitation.deleteByActorId(data.user_id);
  } catch (error) {
    console.error("Coulding delete user data. \n " + data);
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
  consumeMessages(QUEUES.USER_EVENTS, handleUserDeleted);
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
    await bindQueue(`casting_management_${groupName}_events_queue`, `${groupName}s_exchange`, routingKey);
  });

  executeAsyncListeners();
}
