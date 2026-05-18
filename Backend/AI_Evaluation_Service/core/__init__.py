"""Core Services Module

Provides ML pipeline, database operations, and message brokering for evaluation processing.

Metrics Processing (4 total):
  1. emotional_expression_score (0-100)
     - Source: Video emotion recognition model (ResNet50 + 2-layer LSTM)
     - Notebook: Vedio_emotion_Recognition.ipynb
     - Weight: 40%
     
  2. vocal_tone_score (0-100)
     - Source: Audio emotion classification (Wav2Vec2/HuBERT Transformer)
     - Notebook: Audio Model.ipynb
     - Weight: 35%
     
  3. script_alignment_score (0-100)
     - Source: Script alignment model (WhisperX with transcription)
     - Notebook: Script_Alignment Final.ipynb
     - Weight: 25%
     
  4. overall_performance_score (0-100)
     - Calculated: emotional_expression * 0.40 + vocal_tone * 0.35 + script_alignment * 0.25
     - Type: Derived/Calculated

Core Components:
  - database.py: MySQL operations for storing evaluation metrics and results
  - ml_pipeline.py: ML model inference and metric score calculation
  - rabbitmq_manager.py: Event publishing for evaluation completion notifications

Evaluation Data Structure:
  - id: UUID for evaluation
  - media_id: Video media identifier
  - submission_id: Audition submission ID
  - evaluation_status: pending | completed | failed
  - detected_emotions: JSON with emotion classification results
  - ai_feedback: Generated feedback based on scores
  - error_message: Error details if evaluation failed
  - created_at: Timestamp when evaluation was created
  - completed_at: Timestamp when evaluation finished processing
"""

# Core metric definitions for internal processing
CORE_METRICS = {
    'emotional_expression_score': {
        'type': 'decimal',
        'range': [0, 100],
        'precision': 2,
        'weight': 0.40,
        'source_model': 'ResNet50 + 2-layer LSTM',
        'source_notebook': 'Vedio_emotion_Recognition.ipynb',
        'description': 'Video emotion detection and authenticity assessment'
    },
    'vocal_tone_score': {
        'type': 'decimal',
        'range': [0, 100],
        'precision': 2,
        'weight': 0.35,
        'source_model': 'Wav2Vec2/HuBERT Transformer',
        'source_notebook': 'Audio Model.ipynb',
        'description': 'Audio quality, clarity, and emotional tone evaluation'
    },
    'script_alignment_score': {
        'type': 'decimal',
        'range': [0, 100],
        'precision': 2,
        'weight': 0.25,
        'source_model': 'WhisperX (Whisper + X-vectors)',
        'source_notebook': 'Script_Alignment Final.ipynb',
        'description': 'Script adherence accuracy and word-level timing assessment'
    },
    'overall_performance_score': {
        'type': 'decimal',
        'range': [0, 100],
        'precision': 2,
        'calculated': True,
        'formula': 'emotional_expression * 0.40 + vocal_tone * 0.35 + script_alignment * 0.25',
        'description': 'Weighted average of all three metric scores'
    }
}

# Evaluation data field definitions
EVALUATION_FIELDS = {
    'id': {
        'type': 'VARCHAR(36)',
        'description': 'UUID - Unique evaluation identifier',
        'nullable': False
    },
    'media_id': {
        'type': 'VARCHAR(255)',
        'description': 'ID of the video media being evaluated',
        'nullable': False
    },
    'submission_id': {
        'type': 'VARCHAR(255)',
        'description': 'ID of the audition submission',
        'nullable': True
    },
    'evaluation_status': {
        'type': 'VARCHAR(20)',
        'description': 'Current status: pending, completed, failed',
        'nullable': False,
        'default': 'pending'
    },
    'detected_emotions': {
        'type': 'JSON',
        'description': 'JSON object with primary, secondary emotions and confidence',
        'nullable': True
    },
    'ai_feedback': {
        'type': 'TEXT',
        'description': 'Contextual AI-generated feedback based on metric scores',
        'nullable': True
    },
    'error_message': {
        'type': 'TEXT',
        'description': 'Error details if evaluation failed',
        'nullable': True
    },
    'created_at': {
        'type': 'TIMESTAMP',
        'description': 'When the evaluation was created',
        'nullable': False
    },
    'completed_at': {
        'type': 'TIMESTAMP',
        'description': 'When the evaluation was completed',
        'nullable': True
    }
}

# Metric weights for calculating overall performance score
METRIC_WEIGHTS = {
    'emotional_expression_score': 0.40,
    'vocal_tone_score': 0.35,
    'script_alignment_score': 0.25
}

# Metric score field names for database queries
METRIC_FIELD_NAMES = list(CORE_METRICS.keys())

# Status values for evaluations
EVALUATION_STATUS = {
    'PENDING': 'pending',
    'COMPLETED': 'completed',
    'FAILED': 'failed'
}

__all__ = [
    'CORE_METRICS',
    'EVALUATION_FIELDS',
    'METRIC_WEIGHTS',
    'METRIC_FIELD_NAMES',
    'EVALUATION_STATUS'
]
