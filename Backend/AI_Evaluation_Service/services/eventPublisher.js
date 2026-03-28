/**
 * Service for publishing evaluation-related events to RabbitMQ
 */

import { publishMessage, EXCHANGES, ROUTING_KEYS } from '../utils/rabbitmq.js';

export const publishEvaluationCreated = async (evaluationData) => {
  try {
    await publishMessage(
      EXCHANGES.EVALUATIONS,
      ROUTING_KEYS.EVALUATION_CREATED,
      {
        eventType: 'EVALUATION_CREATED',
        timestamp: new Date(),
        data: evaluationData
      }
    );
  } catch (error) {
    console.error('Error publishing evaluation created event:', error);
    throw error;
  }
};

export const publishEvaluationCompleted = async (evaluationData) => {
  try {
    await publishMessage(
      EXCHANGES.EVALUATIONS,
      ROUTING_KEYS.EVALUATION_COMPLETED,
      {
        eventType: 'EVALUATION_COMPLETED',
        timestamp: new Date(),
        data: evaluationData
      }
    );
  } catch (error) {
    console.error('Error publishing evaluation completed event:', error);
    throw error;
  }
};
