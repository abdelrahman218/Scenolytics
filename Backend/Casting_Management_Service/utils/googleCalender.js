import { oauth2Client } from "../config/google.js";
import Actor from "../models/actor.js";
import { Audition } from "../models/audition.js";
import { GoogleCalendarCredentials } from "../models/google_calender_credentials.js";
import { google } from "googleapis";

/** Matches Flutter `formatDateTimeForMysqlUtc` payloads (`YYYY-MM-DD HH:MM:SS` UTC). */
const GOOGLE_CALENDAR_TZ = process.env.GOOGLE_CALENDAR_TIMEZONE || "UTC";

const parseCallbackDateTime = (dateTime) => {
  if (dateTime instanceof Date) return dateTime;
  const raw = String(dateTime).trim();
  const normalized = raw.includes("T") ? raw : raw.replace(" ", "T");
  const withUtc =
    /[zZ]|[+-]\d{2}:?\d{2}$/.test(normalized) ? normalized : `${normalized}Z`;
  const d = new Date(withUtc);
  if (Number.isNaN(d.getTime())) {
    throw new Error(`Invalid callback datetime: ${dateTime}`);
  }
  return d;
};

/** Google Calendar `dateTime` must be local wall time when `timeZone` is set. */
const toGoogleCalendarDateTime = (date) => date.toISOString().slice(0, 19);

const buildEventWindow = (dateTime) => {
  const start = parseCallbackDateTime(dateTime);
  const end = new Date(start.getTime() + 60 * 60 * 1000);
  return {
    start: {
      dateTime: toGoogleCalendarDateTime(start),
      timeZone: GOOGLE_CALENDAR_TZ,
    },
    end: {
      dateTime: toGoogleCalendarDateTime(end),
      timeZone: GOOGLE_CALENDAR_TZ,
    },
  };
};

const refreshAccessToken = async (userCredential) => {
  const valid = await GoogleCalendarCredentials.isAccessTokenValid(
    userCredential.director_id,
  );
  if (valid) return;

  oauth2Client.setCredentials({
    refresh_token: userCredential.google_refresh_token,
  });
  const { credentials } = await oauth2Client.refreshAccessToken();
  await GoogleCalendarCredentials.update(userCredential.id, {
    google_access_token: credentials.access_token,
    google_token_expiry: credentials.expiry_date,
  });
  userCredential.google_access_token = credentials.access_token;
  userCredential.google_token_expiry = credentials.expiry_date;
};

const getGoogleCalenderService = (userCredential) => {
  oauth2Client.setCredentials({
    access_token: userCredential.google_access_token,
    refresh_token: userCredential.google_refresh_token,
    expiry_date: userCredential.google_token_expiry
      ? new Date(userCredential.google_token_expiry).getTime()
      : undefined,
  });
  return google.calendar({ version: "v3", auth: oauth2Client });
};

export const createMeetingEvent = async (submission, dateTime, director_id) => {
  const userCredential =
    await GoogleCalendarCredentials.findByDirectorId(director_id);

  if (!userCredential) {
    return { link: null, event_id: null };
  }

  await refreshAccessToken(userCredential);

  const calendar = getGoogleCalenderService(userCredential);

  const audition = await Audition.findById(submission.audition_id);
  const actor = await Actor.FindById(submission.actor_id);
  const event = {
    summary: `${audition.title} Callback`,
    ...buildEventWindow(dateTime),
    attendees: actor?.email ? [{ email: actor.email }] : [],
    conferenceData: {
      createRequest: {
        requestId: `meet-${Date.now()}`, // must be unique
        conferenceSolutionKey: { type: "hangoutsMeet" },
      },
    },
    // Notify attendees by email
    guestsCanSeeOtherGuests: true,
  };

  const { data } = await calendar.events.insert({
    calendarId: "primary",
    conferenceDataVersion: 1, // required to generate Meet link
    sendUpdates: "all", // emails invitations to attendees
    resource: event,
  });

  return {link: data.conferenceData?.entryPoints?.find(
    (e) => e.entryPointType === "video",
  )?.uri, event_id: data.id};
};

export const updateMeetingEvent = async (event_id, dateTime, director_id) => {
  const userCredential =
    await GoogleCalendarCredentials.findByDirectorId(director_id);

  if (!userCredential) {
    return {link: null, event_id: null};
  }

  await refreshAccessToken(userCredential);

  const calendar = getGoogleCalenderService(userCredential);

  const event = buildEventWindow(dateTime);

  await calendar.events.update({
    calendarId: "primary",
    eventId: event_id,
    conferenceDataVersion: 1, // required to generate Meet link
    sendUpdates: "all", // emails invitations to attendees
    resource: event,
  });
};

export const deleteMeetingEvent = async (event_id, director_id) => {
  const userCredential =
    await GoogleCalendarCredentials.findByDirectorId(director_id);

  if (!userCredential) {
    return Error("No Google Calendar Credentials Found");
  }

  await refreshAccessToken(userCredential);

  const calendar = getGoogleCalenderService(userCredential);

  await calendar.events.delete({
    calendarId: "primary",
    eventId: event_id,
    sendUpdates: "none",
  });
};
