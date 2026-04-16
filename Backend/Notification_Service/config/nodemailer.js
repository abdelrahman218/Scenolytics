import { createTransport } from "nodemailer";
import dotenv from "dotenv";

dotenv.config();

const host = process.env.SMTP_HOST;
const port = process.env.SMTP_PORT;
const user = process.env.SMTP_USER;
const password = process.env.SMTP_PASSWORD;
const email = process.env.SCENOLYTICS_MAIL;

if (!host || !port || !user || !password || !email) {
  throw new Error("Missing SMTP credentials in environment variables");
}

export const smtp = createTransport({
  host,
  port,
  secure: false,
  auth: {
    user,
    pass: password,
  },
}, { from: `"Scenolytics" <${email}>` });
