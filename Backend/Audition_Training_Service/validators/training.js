export const validateTrainingSession = (session) => {
  const errors = [];

  if (!session.actor_id) errors.push('actor_id is required');
  if (!session.media_id) errors.push('media_id is required');

  return {
    isValid: errors.length === 0,
    errors
  };
};

export const validateFeedback = (feedback) => {
  const errors = [];

  if (!feedback.session_id) errors.push('session_id is required');
  if (!feedback.feedback_type) errors.push('feedback_type is required');

  return {
    isValid: errors.length === 0,
    errors
  };
};
