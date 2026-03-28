import { mysql } from "../config/mysql.js";
import bcrypt from "bcrypt";

export default class User {
  static async Create(email, password, role) {
    const hashedPassword = await bcrypt.hash(password, 10);

    await mysql("Users").insert({
      email,
      password: hashedPassword,
      role,
    });

    const result = await mysql("Users").where({ email }).first();

    return result;
  }

  static async Login(email, password) {
    const user = await mysql("Users").where({ email }).first();
    const isPasswordCorrect = await bcrypt.compare(password, user.password);
    
    return user && isPasswordCorrect ? user : null;
  }

  static async DoesUserExist(email) {
    const user = await mysql("Users").where({ email }).first();

    return user ? true : false;
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
