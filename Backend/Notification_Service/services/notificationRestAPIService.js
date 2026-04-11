import { Notification } from "../models/notification.js";
import { NotificationPreference } from "../models/notification_preference.js";

export const getNotificationPreferences = async (req, res, next) => {
  try {
    const preferences = await NotificationPreference.findByUserId(
      req.user.user_id,
    );
    return res.status(200).json(preferences);
  } catch (error) {
    next(error);
  }
};

export const updateNotificationPreferences = async (req, res, next) => {
  try {
    const preferences = await NotificationPreference.upsert(
      req.user.user_id,
      req.body,
    );
    return res.status(200).json(preferences);
  } catch (error) {
    next(error);
  }
};

export const getUserNotifications = async (req, res, next) => {
  try {
    const notifications = await Notification.findByUserId(req.user.user_id);
    return res.status(200).json({ notifications });
  } catch (error) {
    next(error);
  }
};

export const markNotificationAsRead = async (req, res, next) => {
  try {
    const notification = await Notification.markAsRead(
      req.params.notification_id,
    );
    return res.status(200).json(notification);
  } catch (error) {
    return res
      .status(500)
      .json({ message: "Couldn't mark notification as read" });
  }
};

export const deleteNotification = async (req, res, next) => {
  try {
    await Notification.delete(req.params.notification_id);
    return res
      .status(200)
      .json({ message: "Notification deleted successfully" });
  } catch (error) {
    next(error);
  }
};
