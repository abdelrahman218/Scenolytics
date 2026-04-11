import { mysql } from '../config/mysql.js';

export class NotificationPreference {
    static async create(user_id, user_email){
        await mysql('notification_preferences').insert({ user_id, user_email });

        const notification_preference = await mysql('notification_preferences').where({ user_id }).first();
        return notification_preference;
    }

    static async findByUserId(user_id) {
      return mysql('notification_preferences').where({ user_id }).first();
    }
  
    static async upsert(user_id, preferences) {
      const existingPreferences = await this.findByUserId(user_id);
      
      if (!existingPreferences) this.create(user_id);

      await mysql('notification_preferences')
        .where({ user_id })
        .update({
          in_app_submission_notifications: preferences.in_app_submission_notifications,
          in_app_invitation_notifications: preferences.in_app_invitation_notifications,
          email_submission_notifications: preferences.email_submission_notifications,
          email_invitation_notifications: preferences.email_invitation_notifications
        });
        
        const notification_preference = await mysql('notification_preferences').where({ user_id }).first();
        return notification_preference;
    }

    static async deleteByUserId(user_id){
        const affectedRows = await mysql('notification_preferences').where({ user_id }).del();
        return affectedRows;
    }    
}