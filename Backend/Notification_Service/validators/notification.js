export const validateNotification = (notification) => {
  const errors = [];

  if (!notification.user_id) errors.push('user_id is required');
  if (!notification.notification_type) errors.push('notification_type is required');
  if (!notification.title) errors.push('title is required');

  return {
    isValid: errors.length === 0,
    errors
  };
};

export const validatePreferences = (preferences) => {
  const errors = [];

  if (!preferences.user_id) errors.push('user_id is required');

  return {
    isValid: errors.length === 0,
    errors
  };
};
