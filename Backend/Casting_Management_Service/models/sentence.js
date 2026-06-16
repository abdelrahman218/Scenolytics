import { mysql as knex } from '../config/mysql.js';
import { v1 as uuidv1 } from 'uuid';
export class Sentence {
  static async create(sentence) {
    const id = uuidv1();
    await knex('sentences')
      .insert({
        id,
        audition_id: sentence.audition_id,
        emotion: sentence.emotion,
        content: sentence.content,
        sentence_order: sentence.sentence_order
      });

    const result = await knex('sentences').where({ id }).first();
    return result;
  }

  static async findByAuditionId(audition_id) {
    const sentences = await knex('sentences')
      .where({ audition_id })
      .orderBy('sentence_order', 'asc');
    return sentences;
  }

  static async deleteByAuditionId(audition_id) {
    const result = await knex('sentences')
      .where({ audition_id })
      .del();
    return result;
  }
}
