import { mysql as knex } from "../config/mysql.js";

export class Callback {
  static async create(callback) {
    await knex("callbacks").insert({
      audition_id: callback.audition_id,
      audition_submission_id: callback.audition_submission_id,
      actor_id: callback.actor_id,
      callback_datetime: callback.callback_datetime,
      link: callback.link,
      event_id: callback.event_id,
    });

    const result = await knex("callbacks")
      .where({
        audition_submission_id: callback.audition_submission_id,
      })
      .first();
    return result;
  }

  static async findById(id) {
    const callback = await knex("callbacks").where({ id }).first();
    return callback;
  }

  static async findByAuditionId(audition_id) {
    const callbacks = await knex("callbacks")
      .where({ audition_id })
      .orderBy("created_at", "desc");
    return callbacks;
  }

  static async findBySubmissionId(audition_submission_id) {
    const callback = await knex("callbacks")
      .where({ audition_submission_id })
      .first();
    return callback;
  }

  static async findByActorId(actor_id) {
    const callbacks = await knex("callbacks")
      .where({ actor_id })
      .orderBy("created_at", "desc");
    return callbacks;
  }

  static async updateStatus(id, status, directorNotes) {
    const updateData = {
      callback_status: status,
    };

    if (directorNotes) {
      updateData.director_notes = directorNotes;
    }

    await knex("callbacks").where({ id }).update(updateData);

    return await knex("callbacks").where({ id }).first();
  }

  static async update(id, updateFields) {
    await knex("callbacks").where({ id }).update(updateFields);

    return await knex("callbacks").where({ id }).first();
  }

  static async deleteByActorId(actor_id){
    const result = await knex("callbacks").where({ actor_id }).del();
    return result;
  }
}