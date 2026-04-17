# AI Evaluation Service

A FastAPI-based microservice for evaluating audition videos using integrated machine learning models. Part of the Scenolytics microservices ecosystem.

## Overview

This service processes video submissions and provides comprehensive AI-powered evaluation across **5 key metrics** based on available ML models:

- **Emotion Accuracy** (30%) - Consistency of emotion detection between video and audio
- **Voice Clarity** (25%) - Audio quality and articulation
- **Script Alignment** (20%) - Adherence to provided script through transcription matching  
- **Emotion Expression** (15%) - Emotional range and intensity demonstrated
- **Delivery Confidence** (10%) - Speech confidence and delivery quality

## Architecture

### Tech Stack
- **Framework**: FastAPI (Python 3.11)
- **Database**: MySQL 8.0 (async with aiomysql)
- **Message Queue**: RabbitMQ (event-driven architecture)
- **ML Frameworks**: TensorFlow 2.14.0
- **Containerization**: Docker & Docker Compose

### Service Components

```
AI_Evaluation_Service/
├── main.py                          # FastAPI app entry point
├── core/
│   ├── ml_pipeline.py              # ML evaluation orchestration
│   ├── database.py                 # MySQL connection management
│   └── rabbitmq_manager.py         # Event publishing/consuming
├── api/
│   └── routes/
│       ├── evaluation.py           # Video evaluation endpoints
│       └── health.py               # Health check endpoints
├── requirements.txt                # Python dependencies
├── Dockerfile                      # Container configuration
└── ML_MODEL_INTEGRATION.md         # Guide for adding ML models
```

## Quick Start

### 1. Installation

```bash
# Install dependencies
pip install -r requirements.txt
```

### 2. Environment Configuration

Set required environment variables (see `.env.example`):

```bash
# Database
AI_EVALUATION_SERVICE_DATABASE_HOST=user-management-mysql
AI_EVALUATION_SERVICE_DATABASE_NAME=ai_evaluation_db
DATABASE_USER=services_user
DATABASE_PASSWORD=services_password
DATABASE_PORT=3306

# Service
NODE_ENV=development
AI_EVALUATION_SERVICE_PORT=5003

# RabbitMQ
RABBITMQ_URL=amqp://rabbitmq/
```

### 3. Database Setup

```bash
# Initialize database and tables
mysql -h localhost -u root -p < create_database.sql
mysql -h localhost -u root -p < create_tables.sql
```

### 4. Run Service

```bash
# Development
uvicorn main:app --reload --port 5003

# Production
uvicorn main:app --host 0.0.0.0 --port 5003
```

### 5. Docker Deployment

```bash
# Build image
docker build -t scenolytics/ai-evaluation-service:latest .

# Run with docker-compose
docker-compose up -d ai-evaluation-service
```

## API Endpoints

### Evaluation Endpoints

#### Submit Video for Evaluation
```http
POST /api/evaluations/submit
Content-Type: application/json

{
  "video_id": "string",
  "user_id": "string",
  "script_text": "string (optional)",
  "video_url": "string (optional)"
}
```

**Response** (202 Accepted):
```json
{
  "evaluation_id": "uuid",
  "status": "PENDING",
  "message": "Evaluation queued for processing"
}
```

#### Get Evaluation Results
```http
GET /api/evaluations/{evaluation_id}
```

**Response** (200 OK):
```json
{
  "evaluation_id": "uuid",
  "video_id": "string",
  "user_id": "string",
  "overall_score": 85.5,
  "performance_level": "Excellent",
  "metrics": {
    "emotion_accuracy": 88.0,
    "voice_clarity": 90.0,
    "script_alignment": 87.0,
    "emotion_expression": 82.0,
    "delivery_confidence": 80.0
  },
  "strengths": ["Natural emotion", "Clear articulation"],
  "weaknesses": ["Slight script deviation"],
  "recommendations": ["Practice script more"],
  "processed_at": "2024-01-15T10:30:45.123456"
}
```

#### Process Evaluation (Internal)
```http
POST /api/evaluations/process/{evaluation_id}
```

Triggers background evaluation processing. Used internally by job queue.

### Health Check Endpoints

#### Service Health Status
```http
GET /api/health/
```

**Response**:
```json
{
  "status": "healthy",
  "timestamp": "2024-01-15T10:30:45.123456",
  "dependencies": {
    "database": {
      "status": "healthy"
    },
    "rabbitmq": {
      "status": "healthy"
    },
    "ml_models": {
      "status": "degraded",
      "errors": {
        "emotion": "Not loaded"
      }
    }
  }
}
```

#### Readiness Probe (Kubernetes)
```http
GET /api/health/ready
```

Returns 200 only if service is ready to process evaluations.

#### Liveness Probe (Kubernetes)
```http
GET /api/health/live
```

Returns 200 if service is responsive.

## ML Model Integration

The service integrates **3 core ML models** from Scenolytics notebooks:

1. **Video Emotion Recognition** (Vedio_emotion_Recognition.ipynb)
   - CNN-LSTM model for facial emotion detection
   - Input: Video frames (160x160 RGB)
   - Output: Emotion class + confidence

2. **Audio Emotion Classification** (Audio Model.ipynb)
   - Transformer-based speech emotion recognition
   - Input: Audio waveform (16kHz mono)
   - Output: Emotion class + confidence

3. **Script Alignment** (Script_Alignment Final.ipynb)
   - WhisperX transcription model
   - Input: Audio waveform
   - Output: Transcribed text + word-level timestamps
   - Supports: English and Egyptian Arabic

See [ML_MODEL_INTEGRATION.md](./ML_MODEL_INTEGRATION.md) for detailed integration instructions.

### Model Weights

The final evaluation score is calculated as weighted average of 5 metrics:

| Metric | Weight | Source |
|--------|--------|--------|
| Emotion Accuracy | 30% | Video + Audio emotion detection |
| Voice Clarity | 25% | Audio quality analysis |
| Script Alignment | 20% | WhisperX transcription matching |
| Emotion Expression | 15% | Emotional range and intensity |
| Delivery Confidence | 10% | Speech confidence metrics |

## Event-Driven Architecture

### Published Events

**evaluation.completed** - Published when evaluation finishes

```json
{
  "evaluation_id": "uuid",
  "video_id": "string",
  "user_id": "string",
  "overall_score": 85.5,
  "performance_level": "Excellent",
  "metrics": { ... },
  "timestamp": "2024-01-15T10:30:45.123456"
}
```

### Consumed Events

**video.submitted** - Triggers evaluation processing

```json
{
  "video_id": "string",
  "user_id": "string",
  "script_text": "string"
}
```

## Database Schema

### evaluations
Main table storing evaluation records and results

| Field | Type | Description |
|-------|------|-------------|
| evaluation_id | VARCHAR(36) | Primary unique identifier |
| video_id | VARCHAR(100) | Associated video |
| user_id | VARCHAR(36) | User who submitted |
| status | ENUM | PENDING, PROCESSING, COMPLETED, FAILED |
| overall_score | FLOAT | Final 0-100 score |
| performance_level | VARCHAR(50) | Excellent/Good/Average/Below Average/Poor |
| emotion_accuracy | FLOAT | Emotion detection consistency (0-100) |
| voice_clarity | FLOAT | Audio quality score (0-100) |
| script_alignment | FLOAT | Script adherence score (0-100) |
| emotion_expression | FLOAT | Emotional range score (0-100) |
| delivery_confidence | FLOAT | Delivery quality score (0-100) |
| strengths | JSON | Array of strength descriptions |
| weaknesses | JSON | Array of weakness descriptions |
| recommendations | JSON | Array of recommendations |
| created_at | TIMESTAMP | When evaluation was submitted |
| processed_at | TIMESTAMP | When evaluation completed |

### evaluation_history
Audit trail of status changes

### model_performance
Performance metrics for each model inference

## Configuration

### Connection Strings

**Database** (in docker environment):
```
host: user-management-mysql
port: 3306
database: ai_evaluation_db
user: services_user
password: services_password
```

**RabbitMQ** (in docker environment):
```
amqp://rabbitmq/
```

## Performance Characteristics

- **Single Evaluation Processing**: ~30-60 seconds (depends on video length and model complexity)
- **Concurrent Evaluations**: Horizontal scaling via replicas
- **API Response Time**: <100ms for status queries

## Monitoring

### Health Checks
- Database connectivity
- RabbitMQ connectivity
- Model availability
- Service responsiveness

### Logging

Structured logging to stdout with levels:
- `INFO`: Normal operations
- `WARNING`: Retries and recoverable issues
- `ERROR`: Service failures

## Troubleshooting

### Service Won't Start
1. Check database connectivity: `mysql -h localhost -u services_user -p services_password`
2. Check RabbitMQ: `curl http://localhost:15672` (management UI at port 15672)
3. Check logs: `docker logs ai-evaluation-service`

### Evaluations Stuck in PENDING
1. Check if background processor is running
2. Verify RabbitMQ connection
3. Check database for errors in logs

### ML Models Not Loaded
1. Verify model files exist in container
2. Check memory limits: `docker inspect ai-evaluation-service`
3. Review ML_MODEL_INTEGRATION.md for model setup

## Integration with Other Services

### User Management Service
- Receives user deletion events (cascade delete evaluations)
- Sends evaluation results

### Video Processing Service
- Receives processed video references
- Sends evaluation results

### Notification Service
- Publishes evaluation completion events
- Notifies users of results

## Development

### Running Tests
```bash
pytest tests/ -v
```

### Code Style
```bash
# Format code
black .

# Lint
flake8 .

# Type checking
mypy . --ignore-missing-imports
```

## Deployment

### Docker Compose (Development)
```bash
docker-compose up -d ai-evaluation-service
```

### Kubernetes (Production)
See deployment manifests in `k8s/` directory

Health probes configured for K8s:
- Readiness: `/api/health/ready`
- Liveness: `/api/health/live`

## License

Part of Scenolytics Platform

## Support

For issues or questions, contact the development team.
