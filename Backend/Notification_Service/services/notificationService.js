import { v4 as uuidv4 } from 'uuid';
import { Notification, NotificationPreference } from '../models/notification.js';

export const sendNotification = async (user_id, notificationType, title, message, relatedId = null) => {
  try {
    const notificationId = uuidv4();
    await Notification.create({
      id: notificationId,
      user_id,
      notification_type: notificationType,
      title,
      message,
      related_id: relatedId
    });
    return {
      id: notificationId,
      user_id,
      notification_type: notificationType,
      title,
      message,
      is_read: false
    };
  } catch (error) {
    throw new Error(`Failed to send notification: ${error.message}`);
  }
};

export const getUserNotifications = async (user_id) => {
  try {
    const notifications = await Notification.findByUserId(user_id);
    return notifications;
  } catch (error) {
    throw new Error(`Failed to retrieve notifications: ${error.message}`);
  }
};

export const markNotificationAsRead = async (notification_id) => {
  try {
    await Notification.markAsRead(notification_id);
    return await Notification.findById(notification_id);
  } catch (error) {
    throw new Error(`Failed to mark notification as read: ${error.message}`);
  }
};

export const getUnreadCount = async (user_id) => {
  try {
    const result = await Notification.getUnreadCount(user_id);
    return result.count;
  } catch (error) {
    throw new Error(`Failed to get unread count: ${error.message}`);
  }
};

export const deleteNotification = async (notification_id) => {
  try {
    await Notification.delete(notification_id);
    return { message: 'Notification deleted successfully' };
  } catch (error) {
    throw new Error(`Failed to delete notification: ${error.message}`);
  }
};

export const updateNotificationPreferences = async (user_id, preferences) => {
  try {
    await NotificationPreference.update(user_id, preferences);
    return await NotificationPreference.findByUserId(user_id);
  } catch (error) {
    throw new Error(`Failed to update preferences: ${error.message}`);
  }
};

export const getNotificationPreferences = async (user_id) => {
  try {
    const preferences = await NotificationPreference.findByUserId(user_id);
    if (!preferences) throw new Error('Preferences not found');
    return preferences;
  } catch (error) {
    throw new Error(`Failed to retrieve preferences: ${error.message}`);
  }
};
