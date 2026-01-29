import pool from '../config/mysql.js';

class TrainingSession {
  static async create(session) {
    const [result] = await pool.execute(
      'INSERT INTO training_sessions (id, actor_id, media_id, session_status) VALUES (?, ?, ?, ?)',
      [session.id, session.actor_id, session.media_id, session.session_status]
    );
    return result;
  }

  static async findById(id) {
    const [rows] = await pool.execute('SELECT * FROM training_sessions WHERE id = ?', [id]);
    return rows[0];
  }

  static async findByActorId(actor_id) {
    const [rows] = await pool.execute('SELECT * FROM training_sessions WHERE actor_id = ? ORDER BY started_at DESC', [actor_id]);
    return rows;
  }

  static async updateStatus(id, status, duration) {
    const [result] = await pool.execute(
      'UPDATE training_sessions SET session_status = ?, session_duration_seconds = ?, ended_at = NOW() WHERE id = ?',
      [status, duration, id]
    );
    return result;
  }
}

class RealTimeFeedback {
  static async create(feedback) {
    const [result] = await pool.execute(
      'INSERT INTO real_time_feedback (id, session_id, feedback_type, feedback_message, timestamp_seconds, emotion_detected, emotion_confidence) VALUES (?, ?, ?, ?, ?, ?, ?)',
      [feedback.id, feedback.session_id, feedback.feedback_type, feedback.feedback_message, feedback.timestamp_seconds, feedback.emotion_detected, feedback.emotion_confidence]
    );
    return result;
  }

  static async findBySessionId(session_id) {
    const [rows] = await pool.execute('SELECT * FROM real_time_feedback WHERE session_id = ? ORDER BY timestamp_seconds ASC', [session_id]);
    return rows;
  }
}

class TrainingRecommendation {
  static async create(recommendation) {
    const [result] = await pool.execute(
      'INSERT INTO training_recommendations (id, session_id, recommendation_text, recommendation_category, priority) VALUES (?, ?, ?, ?, ?)',
      [recommendation.id, recommendation.session_id, recommendation.recommendation_text, recommendation.recommendation_category, recommendation.priority]
    );
    return result;
  }

  static async findBySessionId(session_id) {
    const [rows] = await pool.execute('SELECT * FROM training_recommendations WHERE session_id = ? ORDER BY priority DESC', [session_id]);
    return rows;
  }
}

export { TrainingSession, RealTimeFeedback, TrainingRecommendation };
