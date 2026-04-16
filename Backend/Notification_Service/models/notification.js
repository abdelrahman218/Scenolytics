import { mysql } from '../config/mysql.js';

export class Notification {
  static async create(notification) {
    await mysql('notifications').insert({
      user_id: notification.user_id,
      notification_type: notification.notification_type,
      title: notification.title,
      message: notification.message,
      related_id: notification.related_id
    });

    const newNotification = await mysql('notifications').where({user_id: notification.user_id}).orderBy('created_at', 'desc').first();
    return newNotification;
  }

  static async findById(id) {
    return mysql('notifications').where({ id }).first();
  }

  static async findByUserId(user_id) {
    return mysql('notifications').where({ user_id }).orderBy('created_at', 'desc');
  }

  static async markAsRead(id) {
    await mysql('notifications')
      .where({ id })
      .update({
        is_read: true,
        read_at: mysql.fn.now()
      });

    const notification = await mysql('notifications').where({ id }).first();
    return notification;
  }

  static async getUnreadCount(user_id) {
    const row = await mysql('notifications')
      .where({ user_id, is_read: false })
      .count({ count: '*' })
      .first();

    return { count: Number(row?.count || 0) };
  }

  static async deleteByUserId(user_id){
    const affectedRows = await mysql('notifications').where({ user_id }).del();
    return affectedRows;
  }

  static async delete(id) {
    const affectedRows = await mysql('notifications').where({ id }).del();
    return affectedRows;
  }
}