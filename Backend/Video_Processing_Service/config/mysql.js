import mysql from 'mysql2/promise';

const pool = mysql.createPool({
  host: process.env.VIDEO_PROCESSING_SERVICE_DATABASE_HOST || 'video-processing-mysql',
  port: process.env.DATABASE_PORT || 3306,
  user: process.env.DATABASE_USER || 'root',
  password: process.env.DATABASE_PASSWORD || '443322@Mo',
  database: process.env.VIDEO_PROCESSING_SERVICE_DATABASE_NAME || 'media_processing_db',
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0
});

export default pool;