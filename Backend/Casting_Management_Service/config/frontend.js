import dotenv from "dotenv";
dotenv.config();

const FRONTEND_LINK = process.env.FRONTEND_LINK;

if (!FRONTEND_LINK) {
  throw new Error("Missing FRONTEND_LINK environment variable");
}

export { FRONTEND_LINK };