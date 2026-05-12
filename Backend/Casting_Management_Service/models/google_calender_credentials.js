import { mysql as knex } from "../config/mysql.js";

export class GoogleCalendarCredentials {

  static async create(credential) {
    await knex("google_calendar_credentials").insert({
      director_id: credential.director_id,
      google_access_token: credential.google_access_token,
      google_refresh_token: credential.google_refresh_token,
      google_token_expiry: credential.google_token_expiry,
    });
    
    return await knex("google_calendar_credentials")
      .where({ director_id: credential.director_id })
      .first();
  }


  static async findById(id) {
    return await knex("google_calendar_credentials").where({ id }).first();
  }

  static async isAccessTokenValid(director_id) {
    const credential = await knex("google_calendar_credentials").where({ director_id }).first();
    return credential.google_token_expiry > new Date().getTime();
  }

  static async findByDirectorId(director_id) {
    return await knex("google_calendar_credentials").where({ director_id }).first();
  }

  static async update(id, updateFields) {
    await knex("google_calendar_credentials").where({ id }).update(updateFields);
    return await knex("google_calendar_credentials").where({ id }).first();
  }

  static async deleteByDirectorId(director_id) {
    return await knex("google_calendar_credentials").where({ director_id }).del();
  }
}
