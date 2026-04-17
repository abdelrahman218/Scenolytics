import pool from '../config/mysql.js';

class Media {
  static async create(media) {
    const [result] = await pool.execute(
      'INSERT INTO media (id, user_id, file_name, file_path, file_type, file_size, mime_type, status) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
      [media.id, media.user_id, media.file_name, media.file_path, media.file_type, media.file_size, media.mime_type, media.status]
    );
    return result;
  }

  static async findById(id) {
    const [rows] = await pool.execute('SELECT * FROM media WHERE id = ?', [id]);
    return rows[0];
  }

  static async findByUserId(user_id) {
    const [rows] = await pool.execute('SELECT * FROM media WHERE user_id = ? ORDER BY created_at DESC', [user_id]);
    return rows;
  }

  static async updateStatus(id, status, errorMessage = null) {
    const [result] = await pool.execute(
      'UPDATE media SET status = ?, error_message = ? WHERE id = ?',
      [status, errorMessage, id]
    );
    return result;
  }

  static async delete(id) {
    const [result] = await pool.execute('DELETE FROM media WHERE id = ?', [id]);
    return result;
  }
}

export default Media;
