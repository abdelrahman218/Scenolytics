/**
 * Inter-service communication utility
 * Handles HTTP calls to other microservices for data validation
 */

const getServiceUrl = (serviceName) => {
  const serviceUrls = {
    identityProvider: process.env.IDENTITY_PROVIDER_SERVICE_URL || 'http://localhost:5000',
    userManagement: process.env.USER_MANAGEMENT_SERVICE_URL || 'http://localhost:5002',
    mediaProcessing: process.env.MEDIA_PROCESSING_SERVICE_URL || 'http://localhost:5001',
    submissionEvaluation: process.env.SUBMISSION_EVALUATION_SERVICE_URL || 'http://localhost:5003',
    ranking: process.env.RANKING_SERVICE_URL || 'http://localhost:5004',
    callbackManagement: process.env.CALLBACK_MANAGEMENT_SERVICE_URL || 'http://localhost:5005',
    notification: process.env.NOTIFICATION_SERVICE_URL || 'http://localhost:5006',
    actorsTraining: process.env.ACTORS_TRAINING_SERVICE_URL || 'http://localhost:5007'
  };
  return serviceUrls[serviceName];
};

export const notificationService = {
  sendNotification: async (user_id, notificationType, title, message, relatedId = null) => {
    try {
      const url = `${getServiceUrl('notification')}/notifications`;
      const response = await fetch(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ user_id, notification_type: notificationType, title, message, related_id: relatedId })
      });
      return await response.json();
    } catch (error) {
      console.error('Error sending notification:', error);
      return null;
    }
  }
};
