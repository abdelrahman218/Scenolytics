import { v4 as uuidv4 } from 'uuid';
import { TrainingSession, RealTimeFeedback, TrainingRecommendation } from '../models/training.js';

export const startTrainingSession = async (actor_id, media_id) => {
  try {
    const sessionId = uuidv4();
    await TrainingSession.create({
      id: sessionId,
      actor_id,
      media_id,
      session_status: 'active'
    });
    return {
      id: sessionId,
      actor_id,
      media_id,
      session_status: 'active'
    };
  } catch (error) {
    throw new Error(`Failed to start training session: ${error.message}`);
  }
};

export const getTrainingSession = async (session_id) => {
  try {
    const session = await TrainingSession.findById(session_id);
    if (!session) throw new Error('Training session not found');
    return session;
  } catch (error) {
    throw new Error(`Failed to retrieve training session: ${error.message}`);
  }
};

export const getActorSessions = async (actor_id) => {
  try {
    const sessions = await TrainingSession.findByActorId(actor_id);
    return sessions;
  } catch (error) {
    throw new Error(`Failed to retrieve actor sessions: ${error.message}`);
  }
};

export const endTrainingSession = async (session_id, duration) => {
  try {
    await TrainingSession.updateStatus(session_id, 'completed', duration);
    return await TrainingSession.findById(session_id);
  } catch (error) {
    throw new Error(`Failed to end training session: ${error.message}`);
  }
};

export const addRealTimeFeedback = async (session_id, feedbackType, feedbackMessage, timestampSeconds, emotionDetected, emotionConfidence) => {
  try {
    const feedbackId = uuidv4();
    await RealTimeFeedback.create({
      id: feedbackId,
      session_id,
      feedback_type: feedbackType,
      feedback_message: feedbackMessage,
      timestamp_seconds: timestampSeconds,
      emotion_detected: emotionDetected,
      emotion_confidence: emotionConfidence
    });
    return {
      id: feedbackId,
      session_id,
      feedback_type: feedbackType,
      feedback_message: feedbackMessage,
      timestamp_seconds: timestampSeconds,
      emotion_detected: emotionDetected,
      emotion_confidence: emotionConfidence
    };
  } catch (error) {
    throw new Error(`Failed to add real-time feedback: ${error.message}`);
  }
};

export const getSessionFeedback = async (session_id) => {
  try {
    const feedback = await RealTimeFeedback.findBySessionId(session_id);
    return feedback;
  } catch (error) {
    throw new Error(`Failed to retrieve session feedback: ${error.message}`);
  }
};

export const addTrainingRecommendation = async (session_id, recommendationText, category, priority = 5) => {
  try {
    const recommendationId = uuidv4();
    await TrainingRecommendation.create({
      id: recommendationId,
      session_id,
      recommendation_text: recommendationText,
      recommendation_category: category,
      priority
    });
    return {
      id: recommendationId,
      session_id,
      recommendation_text: recommendationText,
      recommendation_category: category,
      priority
    };
  } catch (error) {
    throw new Error(`Failed to add training recommendation: ${error.message}`);
  }
};

export const getSessionRecommendations = async (session_id) => {
  try {
    const recommendations = await TrainingRecommendation.findBySessionId(session_id);
    return recommendations;
  } catch (error) {
    throw new Error(`Failed to retrieve session recommendations: ${error.message}`);
  }
};
