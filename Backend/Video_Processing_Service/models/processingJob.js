import pool from '../config/mysql.js';

class ProcessingJob {
  static async create(job) {
    const [result] = await pool.execute(
      'INSERT INTO processing_jobs (id, media_id, job_type, status, priority) VALUES (?, ?, ?, ?, ?)',
      [job.id, job.media_id, job.job_type, job.status, job.priority]
    );
    return result;
  }

  static async findById(id) {
    const [rows] = await pool.execute('SELECT * FROM processing_jobs WHERE id = ?', [id]);
    return rows[0];
  }

  static async findByMediaId(media_id) {
    const [rows] = await pool.execute('SELECT * FROM processing_jobs WHERE media_id = ?', [media_id]);
    return rows;
  }

  static async findByStatus(status) {
    const [rows] = await pool.execute(
      'SELECT * FROM processing_jobs WHERE status = ? ORDER BY priority DESC, created_at ASC LIMIT 10',
      [status]
    );
    return rows;
  }

  static async updateStatus(id, status, result = null, errorMessage = null) {
    const [queryResult] = await pool.execute(
      'UPDATE processing_jobs SET status = ?, result = ?, error_message = ?, completed_at = NOW() WHERE id = ?',
      [status, result ? JSON.stringify(result) : null, errorMessage, id]
    );
    return queryResult;
  }

  static async updateStarted(id) {
    const [result] = await pool.execute(
      'UPDATE processing_jobs SET status = ?, started_at = NOW() WHERE id = ?',
      ['processing', id]
    );
    return result;
  }

  static async delete(id) {
    const [result] = await pool.execute('DELETE FROM processing_jobs WHERE id = ?', [id]);
    return result;
  }
}

export default ProcessingJob;
