"""AI Evaluation Service - API Module

Exposes REST API endpoints for evaluation submission and result retrieval.

Metrics (4 total):
  - emotional_expression_score (0-100): Video emotion detection (ResNet50 + LSTM)
  - vocal_tone_score (0-100): Audio quality and emotional tone (Wav2Vec2/HuBERT)
  - script_alignment_score (0-100): Script adherence accuracy (WhisperX)
  - overall_performance_score (0-100): Weighted average of all metrics

Weight Distribution:
  - Emotional Expression: 40%
  - Vocal/Voice Tone: 35%
  - Script Alignment: 25%

Model Sources:
  1. Video Emotion: Vedio_emotion_Recognition.ipynb (ResNet50 backbone + 2-layer LSTM)
  2. Audio Emotion: Audio Model.ipynb (Transformer-based Wav2Vec2/HuBERT)
  3. Script Alignment: Script_Alignment Final.ipynb (WhisperX transcription + alignment)
"""

# Metric definitions with metadata
METRICS = {
    'emotional_expression_score': {
        'name': 'Emotional Expression',
        'weight': 0.40,
        'description': 'Measures emotional authenticity and consistency in video performance',
        'range': (0, 100),
        'source_model': 'ResNet50 + 2-layer LSTM',
        'source_notebook': 'Vedio_emotion_Recognition.ipynb'
    },
    'vocal_tone_score': {
        'name': 'Vocal Tone',
        'weight': 0.35,
        'description': 'Assesses voice clarity, quality, and emotional authenticity in audio',
        'range': (0, 100),
        'source_model': 'Wav2Vec2/HuBERT Transformer',
        'source_notebook': 'Audio Model.ipynb'
    },
    'script_alignment_score': {
        'name': 'Script Alignment',
        'weight': 0.25,
        'description': 'Evaluates accuracy of script adherence and word-level timing',
        'range': (0, 100),
        'source_model': 'WhisperX (Whisper + X-vectors)',
        'source_notebook': 'Script_Alignment Final.ipynb'
    }
}

# Calculated metric (derived from others)
CALCULATED_METRICS = {
    'overall_performance_score': {
        'name': 'Overall Performance',
        'description': 'Weighted average combining emotional expression, vocal tone, and script alignment',
        'range': (0, 100),
        'formula': 'emotional_expression * 0.40 + vocal_tone * 0.35 + script_alignment * 0.25',
        'calculated': True
    }
}

# Combined metric reference
ALL_METRICS = {**METRICS, **CALCULATED_METRICS}

# Metric field names for database operations
METRIC_FIELD_NAMES = list(METRICS.keys()) + list(CALCULATED_METRICS.keys())

__all__ = [
    'METRICS',
    'CALCULATED_METRICS',
    'ALL_METRICS',
    'METRIC_FIELD_NAMES'
]
