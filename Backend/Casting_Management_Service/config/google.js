import { google } from "googleapis";
import dotenv from "dotenv";
dotenv.config();

const googleClientID = process.env.GOOGLE_CLIENT_ID;
const googleClientSecret = process.env.GOOGLE_CLIENT_SECRET;
const googleRedirectURI = process.env.GOOGLE_REDIRECT_URI;

if (!googleClientID || !googleClientSecret || !googleRedirectURI) {
    throw new Error("Missing Google OAuth configuration");
}

export const SCOPES = [
  'https://www.googleapis.com/auth/calendar.events',
];

export const oauth2Client = new google.auth.OAuth2(
  googleClientID,
  googleClientSecret,
  googleRedirectURI
);