export const validateCallback = (callback) => {
  const errors = [];

  if (!callback.audition_id) errors.push('audition_id is required');
  if (!callback.director_id) errors.push('director_id is required');
  if (!callback.actor_id) errors.push('actor_id is required');

  return {
    isValid: errors.length === 0,
    errors
  };
};

export const validateSubmission = (submission) => {
  const errors = [];

  if (!submission.callback_id) errors.push('callback_id is required');
  if (!submission.media_id) errors.push('media_id is required');

  return {
    isValid: errors.length === 0,
    errors
  };
};
