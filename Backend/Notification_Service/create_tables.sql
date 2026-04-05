USE notification_db;

CREATE TABLE IF NOT EXISTS notifications (
  id VARCHAR(36) PRIMARY KEY,
  user_id VARCHAR(36) NOT NULL,
  notification_type VARCHAR(100),
  title VARCHAR(255),
  message TEXT,
  related_id VARCHAR(36),
  is_read BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  read_at TIMESTAMP NULL,
  INDEX idx_user_id (user_id),
  INDEX idx_notification_type (notification_type),
  INDEX idx_is_read (is_read),
  INDEX idx_created_at (created_at)
);

CREATE TABLE IF NOT EXISTS notification_preferences (
  id VARCHAR(36) PRIMARY KEY,
  user_id VARCHAR(36) NOT NULL UNIQUE,
  email_notifications BOOLEAN DEFAULT TRUE,
  callback_notifications BOOLEAN DEFAULT TRUE,
  submission_notifications BOOLEAN DEFAULT TRUE,
  evaluation_notifications BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_user_id (user_id)
);