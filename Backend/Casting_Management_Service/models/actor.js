import { mysql } from "../config/mysql.js";

export default class Actor {
  static async Create(user_id, email) {
    await mysql("Actors").insert({
      user_id,
      email
    });

    const result = await mysql("Actors").where({ user_id }).first();

    return result;
  }

  static async FindById(user_id) {
    const user = await mysql("Users").where({ user_id }).first();
    return user || null;
  }

  static async Delete(user_id) {
    const isDeleted = await mysql("Users").where({ user_id }).del() == 1;
    return isDeleted;
  }
}
