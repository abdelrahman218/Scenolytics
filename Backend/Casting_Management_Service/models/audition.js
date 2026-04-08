import { mysql as knex } from '../config/mysql.js';

export class Audition {
  static async create(audition, director_id) {
    await knex('auditions')
      .insert({
        director_id,
        title: audition.title,
        description: audition.description,
        type: audition.type,
        candidate_min_height_cm: audition.candidate_min_height_cm || null,
        candidate_max_height_cm: audition.candidate_max_height_cm || null,
        candidate_min_age: audition.candidate_min_age,
        candidate_max_age: audition.candidate_max_age,
        candidate_gender: audition.candidate_gender || 'Both',
        candidate_ethnicity: audition.candidate_ethnicity || 'Any',
        candidate_body_type: audition.candidate_body_type || 'Any'
      });
    
    const result = await knex('auditions').where({director_id, title: audition.title}).first();
    return result;
  }

  static async findById(id) {
    const audition = await knex('auditions')
      .where({ id })
      .first();
    return audition;
  }

  static async findByDirectorId(director_id) {
    const auditions = await knex('auditions')
      .where({ director_id })
      .orderBy('created_at', 'desc');
    return auditions;
  }

  static async update(id, data, director_id) {
    const result = await knex('auditions')
      .where({ id })
      .update({...data, director_id});
    return result;
  }

  static async delete(id) {
    const result = await knex('auditions')
      .where({ id })
      .del();
    return result;
  }

  static async deleteByDirectorId(director_id) {
    const result = await knex('auditions')
      .where({ director_id })
      .del();
    return result;
  }
}
