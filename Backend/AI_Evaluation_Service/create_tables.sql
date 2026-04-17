-- AI Evaluation Service Database Schema
-- 4 Metrics: emotional_expression_score (40%), vocal_tone_score (35%), 
--            script_alignment_score (25%), overall_performance_score (calculated)

CREATE TABLE IF NOT EXISTS evaluations (
    id INT AUTO_INCREMENT PRIMARY KEY,
    evaluation_id VARCHAR(36) UNIQUE NOT NULL,
    media_id VARCHAR(255) NOT NULL,
    submission_id VARCHAR(255),
    
    -- 4 Evaluation Metrics (0-100 scale)
    emotional_expression_score DECIMAL(5,2),  -- 40% weight (from video emotion model)
    vocal_tone_score DECIMAL(5,2),            -- 35% weight (from audio emotion model)
    script_alignment_score DECIMAL(5,2),      -- 25% weight (from script alignment model)
    overall_performance_score DECIMAL(5,2),   -- Calculated: emotion*0.40 + vocal*0.35 + script*0.25
    
    -- Additional evaluation data
    detected_emotions JSON,     -- {primary, secondary, confidence}
    ai_feedback TEXT,          -- Generated feedback based on scores
    evaluation_status VARCHAR(50) DEFAULT 'pending',  -- pending, completed, failed
    error_message TEXT,
    
    -- Timestamps
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP NULL,
    
    -- Indexes for common queries
    INDEX idx_media_id (media_id),
    INDEX idx_submission_id (submission_id),
    INDEX idx_status (evaluation_status),
    INDEX idx_evaluation_id (evaluation_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Evaluation history for audit trail
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

-- Model performance metrics (for monitoring)
CREATE TABLE IF NOT EXISTS model_performance (
    id INT AUTO_INCREMENT PRIMARY KEY,
    evaluation_id VARCHAR(36) NOT NULL,
    model_name VARCHAR(100),
    model_version VARCHAR(50),
    inference_time_ms INT,
    confidence_score FLOAT,
    recorded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (evaluation_id) REFERENCES evaluations(evaluation_id) ON DELETE CASCADE,
    INDEX idx_evaluation_id (evaluation_id),
    INDEX idx_model_name (model_name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
);

-- Model performance tracking
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
);