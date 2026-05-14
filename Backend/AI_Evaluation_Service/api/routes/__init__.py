"""API Routes Module

Defines all REST endpoints for the AI Evaluation Service.

Endpoints:
  POST /evaluations
    - Creates a new evaluation record
    - Request: media_id, submission_id
    - Response: id, media_id, submission_id, evaluation_status
    
  GET /evaluations/:evaluation_id
    - Retrieves complete evaluation with all metrics
    - Response includes all metric scores, feedback, and emotions
    
  PATCH /evaluations/:evaluation_id/scores
    - Updates evaluation metric scores
    - Metrics: emotional_expression_score, vocal_tone_score, script_alignment_score, overall_performance_score
    
  PATCH /evaluations/:evaluation_id/feedback
    - Updates AI feedback and detected emotions
    
  POST /evaluations/:evaluation_id/process/mock
    - Processes evaluation with random/mock scores (for testing)
    
  GET /evaluations/queue/pending
    - Retrieves pending evaluations awaiting processing

Response Metrics in All Evaluation Objects:
  - emotional_expression_score (0-100): Video emotion authenticity
  - vocal_tone_score (0-100): Audio quality and tone
  - script_alignment_score (0-100): Script adherence accuracy
  - overall_performance_score (0-100): Weighted overall score
  - detected_emotions: JSON object with primary, secondary, confidence
  - ai_feedback: Text feedback based on evaluation results
"""

# Route prefixes
ROUTE_GROUPS = {
    'evaluations': '/evaluations',
    'health': '/health',
    'metrics': '/metrics'
}

# Metric fields returned in responses
METRIC_FIELDS = [
    'emotional_expression_score',
    'vocal_tone_score',
    'script_alignment_score',
    'overall_performance_score'
]

# Additional fields in evaluation responses
EVALUATION_RESPONSE_FIELDS = [
    'id',
    'media_id',
    'submission_id',
    'emotional_expression_score',
    'vocal_tone_score',
    'script_alignment_score',
    'overall_performance_score',
    "eye_expression_score",
    'detected_emotions',
    'ai_feedback',
    'evaluation_status',
    'error_message',
    'created_at',
    'completed_at'
]

# Metric score ranges
SCORE_RANGE = {
    'min': 0,
    'max': 100,
    'type': 'integer'
}

__all__ = [
    'ROUTE_GROUPS',
    'METRIC_FIELDS',
    'EVALUATION_RESPONSE_FIELDS',
    'SCORE_RANGE'
]
