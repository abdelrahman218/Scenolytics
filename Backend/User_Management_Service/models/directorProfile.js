import pool from '../config/mysql.js';

class DirectorProfile {
  static async create(profile) {
    const [result] = await pool.execute(
      'INSERT INTO director_profiles (id, user_id, display_name, company_name, company_bio, website, phone, location) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
      [profile.id, profile.user_id, profile.display_name, profile.company_name, profile.company_bio, profile.website, profile.phone, profile.location]
    );
    return result;
  }

  static async findByUserId(user_id) {
    const [rows] = await pool.execute('SELECT * FROM director_profiles WHERE user_id = ?', [user_id]);
    return rows[0];
  }

  static async findById(id) {
    const [rows] = await pool.execute('SELECT * FROM director_profiles WHERE id = ?', [id]);
    return rows[0];
  }

  static async update(id, profile) {
    const [result] = await pool.execute(
      'UPDATE director_profiles SET display_name = ?, company_name = ?, company_bio = ?, website = ?, phone = ?, location = ? WHERE id = ?',
      [profile.display_name, profile.company_name, profile.company_bio, profile.website, profile.phone, profile.location, id]
    );
    return result;
  }

  static async delete(id) {
    const [result] = await pool.execute('DELETE FROM director_profiles WHERE id = ?', [id]);
    return result;
  }
}

export default DirectorProfile;
