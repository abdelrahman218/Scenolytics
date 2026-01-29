import pool from '../config/mysql.js';

class Notification {
  static async create(notification) {
    const [result] = await pool.execute(
      'INSERT INTO notifications (id, user_id, notification_type, title, message, related_id) VALUES (?, ?, ?, ?, ?, ?)',
      [notification.id, notification.user_id, notification.notification_type, notification.title, notification.message, notification.related_id]
    );
    return result;
  }

  static async findById(id) {
    const [rows] = await pool.execute('SELECT * FROM notifications WHERE id = ?', [id]);
    return rows[0];
  }

  static async findByUserId(user_id) {
    const [rows] = await pool.execute('SELECT * FROM notifications WHERE user_id = ? ORDER BY created_at DESC', [user_id]);
    return rows;
  }

  static async markAsRead(id) {
    const [result] = await pool.execute(
      'UPDATE notifications SET is_read = TRUE, read_at = NOW() WHERE id = ?',
      [id]
    );
    return result;
  }

  static async getUnreadCount(user_id) {
    const [rows] = await pool.execute('SELECT COUNT(*) as count FROM notifications WHERE user_id = ? AND is_read = FALSE', [user_id]);
    return rows[0];
  }

  static async delete(id) {
    const [result] = await pool.execute('DELETE FROM notifications WHERE id = ?', [id]);
    return result;
  }
}

class NotificationPreference {
  static async findByUserId(user_id) {
    const [rows] = await pool.execute('SELECT * FROM notification_preferences WHERE user_id = ?', [user_id]);
    return rows[0];
  }

  static async update(user_id, preferences) {
    const [result] = await pool.execute(
      'UPDATE notification_preferences SET email_notifications = ?, callback_notifications = ?, submission_notifications = ?, evaluation_notifications = ? WHERE user_id = ?',
      [preferences.email_notifications, preferences.callback_notifications, preferences.submission_notifications, preferences.evaluation_notifications, user_id]
    );
    return result;
  }
}

export { Notification, NotificationPreference };
