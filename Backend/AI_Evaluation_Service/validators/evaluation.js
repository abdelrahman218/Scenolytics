export const validateEvaluation = (evaluation) => {
  const errors = [];

  if (!evaluation.media_id) {
    errors.push('media_id is required');
  }

  return {
    isValid: errors.length === 0,
    errors
  };
};

export const validateScores = (scores) => {
  const errors = [];

  const scoreFields = ['emotional_expression_score', 'vocal_tone_score', 'body_language_score', 'overall_performance_score'];
  
  scoreFields.forEach(field => {
    if (scores[field] !== undefined) {
      if (typeof scores[field] !== 'number' || scores[field] < 0 || scores[field] > 100) {
        errors.push(`${field} must be a number between 0 and 100`);
      }
    }
  });

  return {
    isValid: errors.length === 0,
    errors
  };
};
