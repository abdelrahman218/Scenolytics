import { oauth2Client } from "../config/google.js";
import Actor from "../models/actor.js";
import { Audition } from "../models/audition.js";
import { GoogleCalendarCredentials } from "../models/google_calender_credentials.js"

const refreshAccessToken = async (userCredential) => {
  if (!GoogleCalendarCredentials.isAccessTokenValid(userCredential.id)) {
    const { tokens } = await oauth2Client.getNewAccessToken();
    await GoogleCalendarCredentials.update(userCredential.id, {
      google_access_token: tokens.access_token,
    });
    userCredential.google_access_token = tokens.access_token;
  }
};

const getGoogleCalenderService = (userCredential) => {
  const tokens = {
    access_token: userCredential.access_token,
    refresh_token: userCredential.refresh_token,
    expiry_date: userCredential.expiry_date,
  };
  oauth2Client.setCredentials(tokens);
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
  const event = {
    summary: audition.title + " Callback",
    start: { dateTime: dateTime },
    end: { dateTime: dateTime + 60 * 60 * 1000 },
    attendees: [{ email: Actor.FindById(submission.actor_id).email }],
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

  const event = {
    start: { dateTime: dateTime },
    end: { dateTime: dateTime + 60 * 60 * 1000 },
  };
  
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
