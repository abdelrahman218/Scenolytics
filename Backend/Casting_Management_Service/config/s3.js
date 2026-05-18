import dotenv from 'dotenv';
import { S3Client } from '@aws-sdk/client-s3';

dotenv.config();

export const s3 = new S3Client({
  endpoint: process.env.AWS_ENDPOINT_URL,       // undefined in prod → real AWS
  region: process.env.AWS_REGION,
  credentials: {
    accessKeyId: process.env.AWS_ACCESS_KEY_ID,
    secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY,
  },
  forcePathStyle: true,   // required for MinIO — it doesn't support virtual-hosted URLs
  requestChecksumCalculation: 'WHEN_REQUIRED',   // only add checksum when explicitly required
  responseChecksumValidation: 'WHEN_REQUIRED',   // same for responses
});