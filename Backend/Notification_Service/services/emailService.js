import { NotificationPreference } from "../models/notification_preference.js";
import { smtp } from "../config/nodemailer.js";

function wantsEmailForType(prefs, notificationType) {
    if (!prefs) return false;
    if (notificationType == "Submission Notification") {
      return Boolean(prefs.email_submission_notifications);
    }
    if (notificationType == "Invitation Notification") {
      return Boolean(prefs.email_invitation_notifications);
    }
    return false;
}

export const sendEmailNotification = async(notification)=>{
    const prefs = await NotificationPreference.findByUserId(notification.user_id);
    if (!wantsEmailForType(prefs, notification.notification_type)) return;

    try {
        await smtp.sendMail({
            to: prefs.user_email,
            subject: notification.title,
            text: notification.message
        });
    } catch (error) {
        console.error(`Error while sending notification (${notification.id}) mail:`, err);
    }
};