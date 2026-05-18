USE actors_training_db;

CREATE TABLE IF NOT EXISTS training_sessions (
  id VARCHAR(36) PRIMARY KEY,
  actor_id VARCHAR(36) NOT NULL,
  media_id VARCHAR(36) NOT NULL,
  session_duration_seconds INT,
  session_status ENUM('active', 'completed', 'paused') DEFAULT 'active',
  started_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  ended_at TIMESTAMP NULL,
  INDEX idx_actor_id (actor_id),
  INDEX idx_session_status (session_status)
);

CREATE TABLE IF NOT EXISTS real_time_feedback (
  id VARCHAR(36) PRIMARY KEY,
  session_id VARCHAR(36) NOT NULL,
  feedback_type VARCHAR(100),
  feedback_message TEXT,
  timestamp_seconds INT,
  emotion_detected VARCHAR(100),
  emotion_confidence DECIMAL(5, 2),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (session_id) REFERENCES training_sessions(id) ON DELETE CASCADE,
  INDEX idx_session_id (session_id),
  INDEX idx_feedback_type (feedback_type)
);

CREATE TABLE IF NOT EXISTS training_recommendations (
  id VARCHAR(36) PRIMARY KEY,
  session_id VARCHAR(36) NOT NULL,
  recommendation_text TEXT,
  recommendation_category VARCHAR(100),
  priority INT DEFAULT 5,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (session_id) REFERENCES training_sessions(id) ON DELETE CASCADE
);
