import { mysql } from "../config/mysql";
import bcrypt from "bcrypt";

export class User {
  static async Create(email, password, role) {
    const hashedPassword = await bcrypt.hash(password, 10);

    const result = await mysql("User").insert({
      email,
      password: hashedPassword,
      role,
    });

    return result;
  }

  static async Login(email, password) {
    const user = await mysql("User").where({ email }).first();
    const isPasswordCorrect = await bcrypt.compare(password, user.password);
    
    return user && isPasswordCorrect ? user : null;
  }

  static async DoesUserExist(email) {
    const user = await mysql("User").where({ email }).first();

    return user ? true : false;
  }
}
