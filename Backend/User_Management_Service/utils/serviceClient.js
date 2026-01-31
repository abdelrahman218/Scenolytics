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

export const identityProviderService = {
  checkUserExists: async (user_id) => {
    try {
      const url = `${getServiceUrl('identityProvider')}/auth/validate/${user_id}`;
      const response = await fetch(url);
      return response.status === 200;
    } catch (error) {
      console.error('Error checking user existence:', error);
      throw new Error(`Failed to validate user with Identity Provider: ${error.message}`);
    }
  }
};
