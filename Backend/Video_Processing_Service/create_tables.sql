USE  media_processing_db;

CREATE TABLE IF NOT EXISTS media (
  id VARCHAR(36) PRIMARY KEY,
  user_id VARCHAR(36) NOT NULL,
  file_name VARCHAR(255) NOT NULL,
  file_path VARCHAR(500) NOT NULL,
  file_type ENUM('audio', 'video') NOT NULL,
  file_size BIGINT NOT NULL,
  mime_type VARCHAR(100),
  status ENUM('uploaded', 'processing', 'completed', 'failed') DEFAULT 'uploaded',
  error_message TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_user_id (user_id)
);

CREATE TABLE IF NOT EXISTS processing_jobs (
  id VARCHAR(36) PRIMARY KEY,
  media_id VARCHAR(36) NOT NULL,
  job_type ENUM('audio_emotion', 'video_emotion', 'extraction') NOT NULL,
  status ENUM('queued', 'processing', 'completed', 'failed') DEFAULT 'queued',
  priority INT DEFAULT 5,
  result JSON,
  error_message TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  started_at TIMESTAMP NULL,
  completed_at TIMESTAMP NULL,
  INDEX idx_media_id (media_id),
  INDEX idx_status (status),
  INDEX idx_priority (priority),
  INDEX idx_created_at (created_at)
);