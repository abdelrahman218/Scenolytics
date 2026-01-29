USE callback_management_db;

CREATE TABLE IF NOT EXISTS callbacks (
  id VARCHAR(36) PRIMARY KEY,
  audition_id VARCHAR(36) NOT NULL,
  director_id VARCHAR(36) NOT NULL,
  actor_id VARCHAR(36) NOT NULL,
  callback_status ENUM('sent', 'accepted', 'declined', 'completed') DEFAULT 'sent',
  script_content LONGTEXT,
  script_url VARCHAR(500),
  sent_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  response_date TIMESTAMP NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_audition_id (audition_id),
  INDEX idx_director_id (director_id),
  INDEX idx_actor_id (actor_id),
  INDEX idx_callback_status (callback_status)
);

CREATE TABLE IF NOT EXISTS callback_submissions (
  id VARCHAR(36) PRIMARY KEY,
  callback_id VARCHAR(36) NOT NULL,
  media_id VARCHAR(36) NOT NULL,
  submission_status ENUM('pending', 'under_review', 'accepted', 'rejected') DEFAULT 'pending',
  submitted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  reviewed_at TIMESTAMP NULL,
  director_notes TEXT,
  FOREIGN KEY (callback_id) REFERENCES callbacks(id) ON DELETE CASCADE,
  INDEX idx_callback_id (callback_id),
  INDEX idx_media_id (media_id),
  INDEX idx_submission_status (submission_status)
);
