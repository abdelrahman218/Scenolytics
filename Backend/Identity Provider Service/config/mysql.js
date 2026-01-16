import { knex } from "knex";
import dotenv from "dotenv";

dotenv.config();

const host = process.env.IDENTITY_PROVIDER_SERVICE_DATABASE_HOST;
const port = process.env.IDENTITY_PROVIDER_SERVICE_DATABASE_PORT;
const user = process.env.IDENTITY_PROVIDER_SERVICE_DATABASE_USER;
const password = process.env.IDENTITY_PROVIDER_SERVICE_DATABASE_PASSWORD;
const database = process.env.IDENTITY_PROVIDER_SERVICE_DATABASE_DATABASE;

if (!host || !port|| !user || !password || !database) {
  throw new Error('Missing database credentials in environment variables');
}

export const mysql = knex({
  client: "mysql",
  connection: {
    host,
    port,
    user,
    password,
    database,
  },
});
