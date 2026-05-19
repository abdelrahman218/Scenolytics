CREATE TABLE IF NOT EXISTS evaluations (
    id INT AUTO_INCREMENT PRIMARY KEY,
    evaluation_id VARCHAR(36) UNIQUE NOT NULL,
    media_id VARCHAR(255) NOT NULL,
    submission_id VARCHAR(255),

    emotional_expression_score DeCIMAL(5,2),
    vocal_tone_score DECIMAL(5,2),
    script_alignment_score DECIMAL(5,2),
    overall_performance_score DECIMAL(5,2),

    eye_expression_score JSON,
    tone_analysis JSON,
    detected_emotions JSON,
    detected_emotions_vocal JSON,
    detected_emotions_video JSON,
    script_alignment_details JSON,
    ai_feedback TEXT,
    evaluation_status VARCHAR(50) DEFAULT 'pending',
    error_message TEXT,

    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP NULL DEFAULT NULL,

    INDEX idx_media_id (media_id),
    INDEX idx_submission_id (submission_id),
    INDEX idx_status (evaluation_status),
    INDEX idx_evaluation_id (evaluation_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS evaluation_history (
    id INT AUTO_INCREMENT PRIMARY KEY,
    evaluation_id VARCHAR(36) NOT NULL,
    previous_status VARCHAR(50),
    new_status VARCHAR(50),
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    changed_by VARCHAR(255),
    error_message TEXT,

    FOREIGN KEY (evaluation_id) REFERENCES evaluations(evaluation_id) ON DELETE CASCADE,
    INDEX idx_evaluation_id (evaluation_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS model_performance (
    id INT AUTO_INCREMENT PRIMARY KEY,
    model_name VARCHAR(100) NOT NULL,
    evaluation_id VARCHAR(36),
    processing_time_ms INT,
    memory_usage_mb FLOAT,
    inference_time_ms INT,
    successful BOOLEAN DEFAULT TRUE,
    error_message VARCHAR(500),
    recorded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (evaluation_id) REFERENCES evaluations(evaluation_id) ON DELETE SET NULL,
    INDEX idx_model_name (model_name),
    INDEX idx_recorded_at (recorded_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
CREATE TABLE IF NOT EXISTS auditions(
    id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
    audition_id VARCHAR(36) UNIQUE NOT NULL,
    media_id VARCHAR(255) NOT NULL,
    submission_id VARCHAR(255),
    actor_id VARCHAR(36),
    director_id VARCHAR(36),
    script TEXT,
    status VARCHAR(50) DEFAULT 'pending',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    INDEX idx_media_id (media_id),
    INDEX idx_submission_id (submission_id),
    INDEX idx_actor_id (actor_id),
    INDEX idx_director_id (director_id)
)
CREATE TABLE IF NOT EXISTS sentences (
  id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
  audition_id CHAR(36) NOT NULL,
  emotion ENUM('neutral', 'calm', 'happy', 'sad', 'angry', 'fearful', 'disgust', 'surprised') NOT NULL,
  content TEXT NOT NULL,
  sentence_order INT NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (audition_id) REFERENCES auditions(id) ON DELETE CASCADE,
  INDEX idx_audition_id (audition_id)
);