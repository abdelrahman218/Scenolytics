import { mysql as knex } from "../config/mysql.js";

export class GoogleCalendarCredentials {
  /** Google `expiry_date` is ms since epoch; MySQL TIMESTAMP needs a Date, not ISO Z strings. */
  static normalizeTokenExpiry(expiry) {
    const date =
      expiry instanceof Date
        ? expiry
        : new Date(typeof expiry === "number" ? expiry : expiry);
    if (Number.isNaN(date.getTime())) {
      throw new Error("Invalid google_token_expiry");
    }
    return date;
  }

  static async create(credential) {
    await knex("google_calendar_credentials").insert({
      director_id: credential.director_id,
      google_access_token: credential.google_access_token,
      google_refresh_token: credential.google_refresh_token,
      google_token_expiry: GoogleCalendarCredentials.normalizeTokenExpiry(
        credential.google_token_expiry,
      ),
    });
    
    return await knex("google_calendar_credentials")
      .where({ director_id: credential.director_id })
      .first();
  }


  static async findById(id) {
    return await knex("google_calendar_credentials").where({ id }).first();
  }

  static async isAccessTokenValid(director_id) {
    const credential = await knex("google_calendar_credentials")
      .where({ director_id })
      .first();
    if (!credential?.google_token_expiry) return false;
    return (
      GoogleCalendarCredentials.normalizeTokenExpiry(
        credential.google_token_expiry,
      ).getTime() > Date.now()
    );
  }

  static async findByDirectorId(director_id) {
    return await knex("google_calendar_credentials").where({ director_id }).first();
  }

  static async update(id, updateFields) {
    const fields = { ...updateFields };
    if (fields.google_token_expiry != null) {
      fields.google_token_expiry = GoogleCalendarCredentials.normalizeTokenExpiry(
        fields.google_token_expiry,
      );
    }
    await knex("google_calendar_credentials").where({ id }).update(fields);
    return await knex("google_calendar_credentials").where({ id }).first();
  }

  static async deleteByDirectorId(director_id) {
    return await knex("google_calendar_credentials").where({ director_id }).del();
  }
}
