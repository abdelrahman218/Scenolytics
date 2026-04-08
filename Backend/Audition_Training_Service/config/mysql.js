import mysql from 'mysql2/promise';

const pool = mysql.createPool({
  host: process.env.AUDITION_TRAINING_SERVICE_DATABASE_HOST || 'localhost',
  port: process.env.DATABASE_PORT || 3306,
  user: process.env.DATABASE_USER,
  password: process.env.DATABASE_PASSWORD,
  database: process.env.AUDITION_TRAINING_SERVICE_DATABASE_NAME || 'actors_training_db',
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0
});

export default pool;
