import { NotificationPreference } from "../models/notification_preference.js";
import { validateJWTTokenForSocketIo } from "../validators/auth.js";

const clients = new Map();

export const setupSocketServer = (socketio) => {
  socketio.use((socket, next) => {
    const jwtToken = socket.handshake.headers.authorization;
    try {
      const user = validateJWTTokenForSocketIo(jwtToken);
      socket.user = user
      next();
    } catch (error) {
      console.log("Error validating JWT token for socket IO");
      console.error(error);
      const err = new Error("not authorized");
      err.data = { content: "Invalid or expired token" };
      next(err);
    }
  });
  
  socketio.on("connection", (socket) => {
    clients.set(socket.user.user_id, socket);
    socket.on("disconnect", () => {
      clients.delete(socket.user.userId);
    });
  });
}

function wantsInAppForType(prefs, notificationType) {
  if (!prefs) return false;
  if (notificationType == "Submission Notification") {
    return Boolean(prefs.in_app_submission_notifications);
  }
  if (notificationType == "Invitation Notification") {
    return Boolean(prefs.in_app_invitation_notifications);
  }
  return false;
}

export async function sendActiveInAppNotification(notification) {
  const prefs = await NotificationPreference.findByUserId(notification.user_id);
  if (!wantsInAppForType(prefs, notification.notification_type)) return;

  const socket = clients.get(notification.user_id);
  if (socket) socket.emit("notification", notification);
}