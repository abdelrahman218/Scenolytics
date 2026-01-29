import pool from '../config/mysql.js';

class ActorProfile {
  static async create(profile) {
    const [result] = await pool.execute(
      'INSERT INTO actor_profiles (id, user_id, bio, height_cm, age, gender, ethnicity, body_type, genres, experience_years, portfolio_url) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [profile.id, profile.user_id, profile.bio, profile.height_cm, profile.age, profile.gender, profile.ethnicity, profile.body_type, profile.genres, profile.experience_years, profile.portfolio_url]
    );
    return result;
  }

  static async findByUserId(user_id) {
    const [rows] = await pool.execute('SELECT * FROM actor_profiles WHERE user_id = ?', [user_id]);
    return rows[0];
  }

  static async findById(id) {
    const [rows] = await pool.execute('SELECT * FROM actor_profiles WHERE id = ?', [id]);
    return rows[0];
  }

  static async update(id, profile) {
    const [result] = await pool.execute(
      'UPDATE actor_profiles SET bio = ?, height_cm = ?, age = ?, gender = ?, ethnicity = ?, body_type = ?, genres = ?, experience_years = ? WHERE id = ?',
      [profile.bio, profile.height_cm, profile.age, profile.gender, profile.ethnicity, profile.body_type, profile.genres, profile.experience_years, id]
    );
    return result;
  }

  static async delete(id) {
    const [result] = await pool.execute('DELETE FROM actor_profiles WHERE id = ?', [id]);
    return result;
  }

  static async searchByAttributes(filters) {
    let query = 'SELECT * FROM actor_profiles WHERE 1=1';
    const params = [];

    if (filters.age_min && filters.age_max) {
      query += ' AND age BETWEEN ? AND ?';
      params.push(filters.age_min, filters.age_max);
    }
    if (filters.gender) {
      query += ' AND gender = ?';
      params.push(filters.gender);
    }
    if (filters.ethnicity) {
      query += ' AND ethnicity = ?';
      params.push(filters.ethnicity);
    }
    if (filters.body_type) {
      query += ' AND body_type = ?';
      params.push(filters.body_type);
    }

    const [rows] = await pool.execute(query, params);
    return rows;
  }
}

export default ActorProfile;
