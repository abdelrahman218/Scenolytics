import { mysql as knex } from '../config/mysql.js';

export class AuditionSubmission {
  static async create(submission) {
    await knex('audition_submissions')
      .insert({
        audition_id: submission.audition_id,
        actor_id: submission.actor_id
      });

    const result = await knex('audition_submissions')
    .where({audition_id: submission.audition_id, actor_id: submission.actor_id})
    .first();
    return result;
  }

  static async findById(id){
    const audition_submission = await knex('audition_submissions')
    .where({ id })
    .first();
    return audition_submission;
  }

  static async findByAuditionId(audition_id) {
    const submissions = await knex('audition_submissions')
      .where({ audition_id })
      .orderBy('submitted_at', 'desc');
    return submissions;
  }

  static async findByActorId(actor_id) {
    const submissions = await knex('audition_submissions')
    .where({ actor_id })
    .orderBy('submitted_at', 'desc');
    return submissions;
  }

  static async findByAuditionIdAndActorId(audition_id, actor_id) {
    const submission = await knex('audition_submissions')
    .where({ audition_id, actor_id })
    .first();
    return submission;
  }

  static async updateStatus(id, status, directorNotes) {
    const updateData = {
      submission_status: status,
      reviewed_at: knex.fn.now()
    };
    if (directorNotes) {
      updateData.director_notes = directorNotes;
    }
    const result = await knex('audition_submissions')
      .where({ id })
      .update(updateData);
    return result;
  }

  static async updateMediaId(id, media_id) {
    const result = await knex('audition_submissions')
    .where({ id })
    .update({ media_id });
    return result;
  }

  static async deleteByActorId(actor_id) {
    const result = await knex('audition_submissions')
      .where({ actor_id })
      .del();
    return result;
  }
}