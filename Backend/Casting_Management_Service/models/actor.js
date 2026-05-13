import { mysql } from "../config/mysql.js";

export default class Actor {
  static async Create(user_id, email) {
    await mysql("actors").insert({
      user_id,
      email
    });

    const result = await mysql("actors").where({ user_id }).first();

    return result;
  }

  static async FindById(user_id) {
    const user = await mysql("actors").where({ user_id }).first();
    return user;
  }

  static async Delete(user_id) {
    const isDeleted = await mysql("actors").where({ user_id }).del() == 1;
    return isDeleted;
  }
}
