import { Audition } from "../models/audition"
import { AuditionInvitation } from "../models/audition_invitation";
import { AuditionSubmission } from "../models/audition_submission";
import { consumeMessages, QUEUES, ROUTING_KEYS } from "./rabbitmq"

export const executeAsyncListeners = () => {

    consumeMessages(QUEUES.USER_EVENTS, async (type, content) => {
        if (type == ROUTING_KEYS.USER_DELETED){
            try {
                await Audition.deleteByDirectorId(content.user_id);
                await AuditionSubmission.deleteByActorId(content.user_id);
                await AuditionInvitation.deleteByActorId(content.user_id);
            } catch (error) {
                console.error("Coulding delete user data. /n " + content.toString());
            }
        }
    })

    consumeMessages(QUEUES.VIDEO_EVENTS, async (type, content) => {
        if (type == ROUTING_KEYS.VIDEO_UPLOADED){
            try {
                await AuditionSubmission.updateMediaId(content.audition_id, content.media_id);
            } catch (error) {
                console.error("Coulding update media id. /n " + content.toString());
            }
        }
    })
}