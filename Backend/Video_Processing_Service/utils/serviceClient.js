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

export const userManagementService = {
  getActorProfile: async (user_id) => {
    try {
      const url = `${getServiceUrl('userManagement')}/actors/${user_id}/profile`;
      const response = await fetch(url);
      if (response.status === 404) return null;
      return await response.json();
    } catch (error) {
      console.error('Error getting actor profile:', error);
      return null;
    }
  },

  getDirectorProfile: async (user_id) => {
    try {
      const url = `${getServiceUrl('userManagement')}/directors/${user_id}/profile`;
      const response = await fetch(url);
      if (response.status === 404) return null;
      return await response.json();
    } catch (error) {
      console.error('Error getting director profile:', error);
      return null;
    }
  }
};

export const mediaProcessingService = {
  getMedia: async (media_id) => {
    try {
      const url = `${getServiceUrl('mediaProcessing')}/media/${media_id}`;
      const response = await fetch(url);
      if (response.status === 404) return null;
      return await response.json();
    } catch (error) {
      console.error('Error getting media:', error);
      return null;
    }
  },

  createProcessingJob: async (media_id, job_type, priority = 5) => {
    try {
      const url = `${getServiceUrl('mediaProcessing')}/jobs`;
      const response = await fetch(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ media_id, job_type, priority })
      });
      return await response.json();
    } catch (error) {
      console.error('Error creating processing job:', error);
      throw new Error(`Failed to create processing job: ${error.message}`);
    }
  }
};

export const submissionEvaluationService = {
  getEvaluation: async (evaluation_id) => {
    try {
      const url = `${getServiceUrl('submissionEvaluation')}/evaluations/${evaluation_id}`;
      const response = await fetch(url);
      if (response.status === 404) return null;
      return await response.json();
    } catch (error) {
      console.error('Error getting evaluation:', error);
      return null;
    }
  },

  createEvaluation: async (media_id, submission_id = null) => {
    try {
      const url = `${getServiceUrl('submissionEvaluation')}/evaluations`;
      const response = await fetch(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ media_id, submission_id })
      });
      return await response.json();
    } catch (error) {
      console.error('Error creating evaluation:', error);
      throw new Error(`Failed to create evaluation: ${error.message}`);
    }
  }
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
      // Don't throw, notifications are not critical
      return null;
    }
  }
};

export const callbackManagementService = {
  getCallback: async (callback_id) => {
    try {
      const url = `${getServiceUrl('callbackManagement')}/callbacks/${callback_id}`;
      const response = await fetch(url);
      if (response.status === 404) return null;
      return await response.json();
    } catch (error) {
      console.error('Error getting callback:', error);
      return null;
    }
  }
};

export const rankingService = {
  getRankings: async (audition_id) => {
    try {
      const url = `${getServiceUrl('ranking')}/rankings/${audition_id}`;
      const response = await fetch(url);
      if (response.status === 404) return [];
      return await response.json();
    } catch (error) {
      console.error('Error getting rankings:', error);
      return [];
    }
  }
};

export const actorsTrainingService = {
  getSession: async (session_id) => {
    try {
      const url = `${getServiceUrl('actorsTraining')}/sessions/${session_id}`;
      const response = await fetch(url);
      if (response.status === 404) return null;
      return await response.json();
    } catch (error) {
      console.error('Error getting training session:', error);
      return null;
    }
  }
};
