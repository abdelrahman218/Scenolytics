import { v4 as uuidv4 } from 'uuid';
import Evaluation from '../models/evaluation.js';

export const createEvaluation = async (media_id, submission_id = null) => {
  try {
    const evaluationId = uuidv4();
    await Evaluation.create({
      id: evaluationId,
      media_id,
      submission_id,
      evaluation_status: 'pending'
    });
    return {
      id: evaluationId,
      media_id,
      submission_id,
      evaluation_status: 'pending'
    };
  } catch (error) {
    throw new Error(`Failed to create evaluation: ${error.message}`);
  }
};

export const getEvaluationById = async (evaluationId) => {
  try {
    const evaluation = await Evaluation.findById(evaluationId);
    if (!evaluation) {
      throw new Error('Evaluation not found');
    }
    return evaluation;
  } catch (error) {
    throw new Error(`Failed to retrieve evaluation: ${error.message}`);
  }
};

export const updateEvaluationScores = async (evaluationId, scores) => {
  try {
    await Evaluation.updateScores(evaluationId, scores);
    return await Evaluation.findById(evaluationId);
  } catch (error) {
    throw new Error(`Failed to update evaluation scores: ${error.message}`);
  }
};

export const updateEvaluationFeedback = async (evaluationId, feedback, detectedEmotions) => {
  try {
    await Evaluation.updateFeedback(evaluationId, feedback, JSON.stringify(detectedEmotions));
    return await Evaluation.findById(evaluationId);
  } catch (error) {
    throw new Error(`Failed to update evaluation feedback: ${error.message}`);
  }
};

export const handleEvaluationError = async (evaluationId, errorMessage) => {
  try {
    await Evaluation.updateError(evaluationId, errorMessage);
    return await Evaluation.findById(evaluationId);
  } catch (error) {
    throw new Error(`Failed to handle evaluation error: ${error.message}`);
  }
};

export const getPendingEvaluations = async () => {
  try {
    const evaluations = await Evaluation.getByStatus('pending');
    return evaluations;
  } catch (error) {
    throw new Error(`Failed to retrieve pending evaluations: ${error.message}`);
  }
};
