USE user_management_db;

CREATE TABLE IF NOT EXISTS actor_profiles (
  id VARCHAR(36) PRIMARY KEY,
  user_id VARCHAR(36) NOT NULL UNIQUE,
  bio TEXT,
  height_cm INT,
  age INT,
  gender VARCHAR(50),
  ethnicity VARCHAR(100),
  body_type VARCHAR(50),
  personality_traits JSON,
  genres JSON,
  experience_years INT,
  portfolio_url VARCHAR(500),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_user_id (user_id),
  INDEX idx_age (age),
  INDEX idx_gender (gender),
  INDEX idx_ethnicity (ethnicity),
  INDEX idx_body_type (body_type)
);

CREATE TABLE IF NOT EXISTS director_profiles (
  id VARCHAR(36) PRIMARY KEY,
  user_id VARCHAR(36) NOT NULL UNIQUE,
  company_name VARCHAR(255),
  company_bio TEXT,
  website VARCHAR(500),
  phone VARCHAR(20),
  location VARCHAR(255),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_user_id (user_id)
);

CREATE TABLE IF NOT EXISTS user_attributes (
  id VARCHAR(36) PRIMARY KEY,
  user_id VARCHAR(36) NOT NULL,
  attribute_name VARCHAR(100) NOT NULL,
  attribute_value VARCHAR(255),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_user_id (user_id),
  INDEX idx_attribute_name (attribute_name)
);