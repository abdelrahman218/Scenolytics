import express from 'express';
import { validateNotification, validatePreferences } from '../validators/notification.js';
import * as notificationService from '../services/notificationService.js';

const router = express.Router();

// Send notification
router.post('/notifications', async (req, res, next) => {
  try {
    const validation = validateNotification(req.body);
    if (!validation.isValid) {
      return res.status(400).json({ errors: validation.errors });
    }

    const notification = await notificationService.sendNotification(
      req.body.user_id,
      req.body.notification_type,
      req.body.title,
      req.body.message,
      req.body.related_id
    );
    res.status(201).json(notification);
  } catch (error) {
    next(error);
  }
});

// Get user notifications
router.get('/notifications/:user_id/notifications', async (req, res, next) => {
  try {
    const notifications = await notificationService.getUserNotifications(req.params.user_id);
    res.status(200).json(notifications);
  } catch (error) {
    next(error);
  }
});

// Get unread count
router.get('/notifications/:user_id/notifications/unread/count', async (req, res, next) => {
  try {
    const count = await notificationService.getUnreadCount(req.params.user_id);
    res.status(200).json({ unread_count: count });
  } catch (error) {
    next(error);
  }
});

// Mark as read
router.patch('/notifications/:notification_id/read', async (req, res, next) => {
  try {
    const notification = await notificationService.markNotificationAsRead(req.params.notification_id);
    res.status(200).json(notification);
  } catch (error) {
    next(error);
  }
});

// Delete notification
router.delete('/notifications/:notification_id', async (req, res, next) => {
  try {
    const result = await notificationService.deleteNotification(req.params.notification_id);
    res.status(200).json(result);
  } catch (error) {
    next(error);
  }
});

// Get notification preferences
router.get('/notifications/:user_id/preferences', async (req, res, next) => {
  try {
    const preferences = await notificationService.getNotificationPreferences(req.params.user_id);
    res.status(200).json(preferences);
  } catch (error) {
    next(error);
  }
});

// Update notification preferences
router.patch('/notifications/:user_id/preferences', async (req, res, next) => {
  try {
    const preferences = await notificationService.updateNotificationPreferences(req.params.user_id, req.body);
    res.status(200).json(preferences);
  } catch (error) {
    next(error);
  }
});

export default router;
