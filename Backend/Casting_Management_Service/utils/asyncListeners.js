import { Audition } from "../models/audition.js";
import { AuditionInvitation } from "../models/audition_invitation.js";
import { AuditionSubmission } from "../models/audition_submission.js";
import { consumeMessages, QUEUES } from "./rabbitmq.js";

export const executeAsyncListeners = () => {
  consumeMessages(QUEUES.USER_EVENTS, async (content) => {
    try {
      await Audition.deleteByDirectorId(content.user_id);
      await AuditionSubmission.deleteByActorId(content.user_id);
      await AuditionInvitation.deleteByActorId(content.user_id);
    } catch (error) {
      console.error("Coulding delete user data. /n " + content);
    }
  });

  consumeMessages(QUEUES.VIDEO_EVENTS, async (content) => {
    try {
      await AuditionSubmission.updateMediaId(
        content.audition_id,
        content.media_id,
      );
    } catch (error) {
      console.error("Coulding update media id. /n " + content);
    }
  });
};
