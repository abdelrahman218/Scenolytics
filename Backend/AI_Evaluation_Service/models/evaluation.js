import pool from '../config/mysql.js';

class Evaluation {
  static async create(evaluation) {
    const [result] = await pool.execute(
      'INSERT INTO evaluations (id, media_id, submission_id, evaluation_status) VALUES (?, ?, ?, ?)',
      [evaluation.id, evaluation.media_id, evaluation.submission_id, evaluation.evaluation_status]
    );
    return result;
  }

  static async findById(id) {
    const [rows] = await pool.execute('SELECT * FROM evaluations WHERE id = ?', [id]);
    return rows[0];
  }

  static async findByMediaId(media_id) {
    const [rows] = await pool.execute('SELECT * FROM evaluations WHERE media_id = ?', [media_id]);
    return rows[0];
  }

  // New score weights: Emotion 40%, Voice 35%, Script 25%
  static async updateScores(id, scores) {
    const [result] = await pool.execute(
      'UPDATE evaluations SET emotional_expression_score = ?, vocal_tone_score = ?, script_alignment_score = ?, overall_performance_score = ?, evaluation_status = ? WHERE id = ?',
      [
        scores.emotional_expression_score,    // 40%
        scores.vocal_tone_score,              // 35%
        scores.script_alignment_score,        // 25% 
        scores.overall_performance_score,
        'completed',
        id
      ]
    );
    return result;
  }

  static async updateFeedback(id, feedback, detected_emotions) {
    const [result] = await pool.execute(
      'UPDATE evaluations SET ai_feedback = ?, detected_emotions = ?, completed_at = NOW() WHERE id = ?',
      [feedback, detected_emotions, id]
    );
    return result;
  }

  static async updateError(id, errorMessage) {
    const [result] = await pool.execute(
      'UPDATE evaluations SET evaluation_status = ?, error_message = ? WHERE id = ?',
      ['failed', errorMessage, id]
    );
    return result;
  }

  static async getByStatus(status) {
    const [rows] = await pool.execute('SELECT * FROM evaluations WHERE evaluation_status = ? LIMIT 10', [status]);
    return rows;
  }
}

export default Evaluation;