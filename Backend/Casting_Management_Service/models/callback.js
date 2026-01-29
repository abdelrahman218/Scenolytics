import pool from '../config/mysql.js';

class Callback {
  static async create(callback) {
    const [result] = await pool.execute(
      'INSERT INTO callbacks (id, audition_id, director_id, actor_id, callback_status, script_content, script_url) VALUES (?, ?, ?, ?, ?, ?, ?)',
      [callback.id, callback.audition_id, callback.director_id, callback.actor_id, callback.callback_status, callback.script_content, callback.script_url]
    );
    return result;
  }

  static async findById(id) {
    const [rows] = await pool.execute('SELECT * FROM callbacks WHERE id = ?', [id]);
    return rows[0];
  }

  static async findByActorId(actor_id) {
    const [rows] = await pool.execute('SELECT * FROM callbacks WHERE actor_id = ? ORDER BY sent_at DESC', [actor_id]);
    return rows;
  }

  static async findByAuditionId(audition_id) {
    const [rows] = await pool.execute('SELECT * FROM callbacks WHERE audition_id = ?', [audition_id]);
    return rows;
  }

  static async updateStatus(id, status, response_date = null) {
    const [result] = await pool.execute(
      'UPDATE callbacks SET callback_status = ?, response_date = ? WHERE id = ?',
      [status, response_date, id]
    );
    return result;
  }

  static async delete(id) {
    const [result] = await pool.execute('DELETE FROM callbacks WHERE id = ?', [id]);
    return result;
  }
}

class CallbackSubmission {
  static async create(submission) {
    const [result] = await pool.execute(
      'INSERT INTO callback_submissions (id, callback_id, media_id, submission_status) VALUES (?, ?, ?, ?)',
      [submission.id, submission.callback_id, submission.media_id, submission.submission_status]
    );
    return result;
  }

  static async findById(id) {
    const [rows] = await pool.execute('SELECT * FROM callback_submissions WHERE id = ?', [id]);
    return rows[0];
  }

  static async findByCallbackId(callback_id) {
    const [rows] = await pool.execute('SELECT * FROM callback_submissions WHERE callback_id = ?', [callback_id]);
    return rows;
  }

  static async updateStatus(id, status, director_notes = null) {
    const [result] = await pool.execute(
      'UPDATE callback_submissions SET submission_status = ?, director_notes = ?, reviewed_at = NOW() WHERE id = ?',
      [status, director_notes, id]
    );
    return result;
  }
}

export { Callback, CallbackSubmission };
