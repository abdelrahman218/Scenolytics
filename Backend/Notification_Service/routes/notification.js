import express from 'express';
import { validateUpdateNotificationDataValues, validateUpdateNotificationPreferenceRequiredData } from '../validators/notification.js';
import { deleteNotification, getNotificationPreferences, getUserNotifications, markNotificationAsRead, updateNotificationPreferences } from '../services/notificationRestAPIService.js';

const router = express.Router();

//Notification Preferences Endpoints

// Get notification preferences
router.get('/notifications/preferences', getNotificationPreferences);

// Update notification preferences
router.patch('/notifications/preferences', validateUpdateNotificationPreferenceRequiredData, validateUpdateNotificationDataValues, updateNotificationPreferences);

//Notification Endpoints

// Get user notifications
router.get('/notifications/', getUserNotifications);

// Mark as read
router.patch('/notifications/:notification_id/read', markNotificationAsRead);

// Delete notification
router.delete('/notifications/:notification_id', deleteNotification);

export default router;
