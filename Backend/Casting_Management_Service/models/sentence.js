import { mysql as knex } from '../config/mysql.js';

export class Sentence {
  static async create(sentence) {
    await knex('sentences')
      .insert({
        audition_id: sentence.audition_id,
        emotion: sentence.emotion,
        content: sentence.content
      });

    const result = await knex('sentences').where({audition_id: sentence.audition_id}).first();
    return result;
  }

  static async findByAuditionId(audition_id) {
    const sentences = await knex('sentences')
      .where({ audition_id })
      .orderBy('updated_at', 'asc');
    return sentences;
  }

  static async deleteByAuditionId(audition_id) {
    const result = await knex('sentences')
      .where({ audition_id })
      .del();
    return result;
  }
}
