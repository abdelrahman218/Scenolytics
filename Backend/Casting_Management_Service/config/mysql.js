import knex from "knex";
import dotenv from "dotenv";

dotenv.config();

const host = process.env.CASTING_MANAGEMENT_SERVICE_DATABASE_HOST;
const port = process.env.DATABASE_PORT || 3306;
const user = process.env.DATABASE_USER;
const password = process.env.DATABASE_PASSWORD;
const database = process.env.CASTING_MANAGEMENT_SERVICE_DATABASE_NAME;

if (!host || !port|| !user || !password || !database) {
  throw new Error('Missing database credentials in environment variables');
}

export const mysql = knex({
  client: "mysql2",
  connection: {
    host,
    port,
    user,
    password,
    database,
  },
});
