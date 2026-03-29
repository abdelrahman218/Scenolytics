USE callback_management_db;

CREATE TABLE IF NOT EXISTS sentences (
  id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
  audition_id CHAR(36) NOT NULL,
  emotion ENUM('neutral', 'calm', 'happy', 'sad', 'angry', 'fearful', 'disgust', 'surprised') NOT NULL,
  content TEXT NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (audition_id) REFERENCES auditions(id) ON DELETE CASCADE,
  INDEX idx_audition_id (audition_id),
);

CREATE TABLE IF NOT EXISTS auditions (
  id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
  director_id CHAR(36) NOT NULL,
  title VARCHAR(255) NOT NULL,
  description TEXT,
  type ENUM('Audio', 'Video') NOT NULL,
  candidate_min_height_cm INT,
  candidate_max_height_cm INT,
  candidate_min_age INT NOT NULL,
  candidate_max_age INT NOT NULL,
  candidate_gender ENUM('Male', 'Female', 'Both') NOT NULL,
  candidate_ethnicity ENUM('White', 'Black', 'Asian', 'Arab', 'Any') DEFAULT 'Any',
  candidate_body_type ENUM('Slim', 'Athletic', 'Average', 'Heavyset', 'Any') DEFAULT 'Any',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_director_id (director_id),
);

CREATE TABLE IF NOT EXISTS audition_submissions (
  id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
  audition_id CHAR(36) NOT NULL,
  actor_id CHAR(36) NOT NULL,
  media_id CHAR(36) DEFAULT NULL,
  submission_status ENUM('pending', 'under_review', 'accepted', 'rejected') DEFAULT 'pending',
  submitted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  reviewed_at TIMESTAMP DEFAULT NULL,
  director_notes TEXT DEFAULT NULL,
  FOREIGN KEY (audition_id) REFERENCES auditions(id) ON DELETE CASCADE,
  INDEX idx_audition_id (audition_id),
  INDEX idx_actor_id (actor_id),
  INDEX idx_submission_status (submission_status)
);

CREATE TABLE IF NOT EXISTS audition_invitations (
  id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
  audition_id CHAR(36) NOT NULL,
  actor_id CHAR(36) NOT NULL,
  invitation_status ENUM('pending', 'accepted', 'declined') DEFAULT 'pending',
  invited_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  responded_at TIMESTAMP DEFAULT NULL,
  FOREIGN KEY (audition_id) REFERENCES auditions(id) ON DELETE CASCADE,
  INDEX idx_audition_id (audition_id),
  INDEX idx_actor_id (actor_id)
);