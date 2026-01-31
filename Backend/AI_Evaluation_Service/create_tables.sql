USE submission_evaluation_db;

CREATE TABLE IF NOT EXISTS evaluations (
  id VARCHAR(36) PRIMARY KEY,
  media_id VARCHAR(36) NOT NULL,
  submission_id VARCHAR(36),
  emotional_expression_score DECIMAL(5, 2),
  vocal_tone_score DECIMAL(5, 2),
  overall_performance_score DECIMAL(5, 2),
  detected_emotions JSON,
  ai_feedback TEXT,
  evaluation_status ENUM('pending', 'completed', 'failed') DEFAULT 'pending',
  error_message TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  completed_at TIMESTAMP NULL,
  INDEX idx_media_id (media_id),
  INDEX idx_submission_id (submission_id),
  INDEX idx_evaluation_status (evaluation_status)
);

CREATE TABLE IF NOT EXISTS evaluation_metrics (
  id VARCHAR(36) PRIMARY KEY,
  evaluation_id VARCHAR(36) NOT NULL,
  metric_name VARCHAR(100),
  metric_value DECIMAL(10, 4),
  INDEX idx_evaluation_id (evaluation_id)
);