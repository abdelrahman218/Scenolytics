/**
 * Inter-service communication utility
 * Handles HTTP calls to other microservices for data validation
 * Uses Docker service names for internal communication
 */

const getServiceUrl = (serviceName) => {
  const serviceUrls = {
    identityProvider: process.env.IDENTITY_PROVIDER_SERVICE_URL || 'http://identity-provider-service-1:5000',
    userManagement: process.env.USER_MANAGEMENT_SERVICE_URL || 'http://user-management-service-1:5009',
    videoProcessing: process.env.VIDEO_PROCESSING_SERVICE_URL || 'http://video-processing-service-1:5002',
    aiEvaluation: process.env.AI_EVALUATION_SERVICE_URL || 'http://ai-evaluation-service-1:5003',
    castingManagement: process.env.CASTING_MANAGEMENT_SERVICE_URL || 'http://casting-management-service-1:5004',
    notification: process.env.NOTIFICATION_SERVICE_URL || 'http://notification-service-1:5005',
    auditionTraining: process.env.AUDITION_TRAINING_SERVICE_URL || 'http://audition-training-service-1:5001'
  };
  return serviceUrls[serviceName];
};

// ===== Identity Provider Service =====
export const identityProviderService = {
  checkUserExists: async (user_id) => {
    try {
      const url = `${getServiceUrl('identityProvider')}/auth/validate/${user_id}`;
      console.log(`[identityProviderService] Calling: ${url}`);
      const response = await fetch(url);
      return response.status === 200;
    } catch (error) {
      console.error('[identityProviderService] Error checking user existence:', error.message);
      throw new Error(`Failed to validate user with Identity Provider: ${error.message}`);
    }
  }
};

// ===== User Management Service =====
export const userManagementService = {
  getActorProfile: async (user_id) => {
    try {
      const url = `${getServiceUrl('userManagement')}/actors/${user_id}/profile`;
      console.log(`[userManagementService] Calling: ${url}`);
      const response = await fetch(url);
      if (response.status === 404) return null;
      return await response.json();
    } catch (error) {
      console.error('[userManagementService] Error getting actor profile:', error.message);
      return null;
    }
  },

  getDirectorProfile: async (user_id) => {
    try {
      const url = `${getServiceUrl('userManagement')}/directors/${user_id}/profile`;
      console.log(`[userManagementService] Calling: ${url}`);
      const response = await fetch(url);
      if (response.status === 404) return null;
      return await response.json();
    } catch (error) {
      console.error('[userManagementService] Error getting director profile:', error.message);
      return null;
    }
  }
};

// ===== Video Processing Service =====
export const videoProcessingService = {
  getMedia: async (media_id) => {
    try {
      const url = `${getServiceUrl('videoProcessing')}/media/${media_id}`;
      console.log(`[videoProcessingService] Calling: ${url}`);
      const response = await fetch(url);
      if (response.status === 404) return null;
      return await response.json();
    } catch (error) {
      console.error('[videoProcessingService] Error getting media:', error.message);
      return null;
    }
  },

  createProcessingJob: async (media_id, job_type, priority = 5) => {
    try {
      const url = `${getServiceUrl('videoProcessing')}/jobs`;
      console.log(`[videoProcessingService] Creating job: ${url}`);
      const response = await fetch(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ media_id, job_type, priority })
      });
      if (!response.ok) {
        throw new Error(`HTTP ${response.status}`);
      }
      return await response.json();
    } catch (error) {
      console.error('[videoProcessingService] Error creating processing job:', error.message);
      throw new Error(`Failed to create processing job: ${error.message}`);
    }
  }
};

// ===== AI Evaluation Service =====
export const aiEvaluationService = {
  getEvaluation: async (evaluation_id) => {
    try {
      const url = `${getServiceUrl('aiEvaluation')}/evaluations/${evaluation_id}`;
      console.log(`[aiEvaluationService] Calling: ${url}`);
      const response = await fetch(url);
      if (response.status === 404) return null;
      return await response.json();
    } catch (error) {
      console.error('[aiEvaluationService] Error getting evaluation:', error.message);
      return null;
    }
  },

  createEvaluation: async (media_id, submission_id = null) => {
    try {
      const url = `${getServiceUrl('aiEvaluation')}/evaluations`;
      console.log(`[aiEvaluationService] Creating evaluation: ${url}`);
      const response = await fetch(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ media_id, submission_id })
      });
      if (!response.ok) {
        throw new Error(`HTTP ${response.status}: ${response.statusText}`);
      }
      return await response.json();
    } catch (error) {
      console.error('[aiEvaluationService] Error creating evaluation:', error.message);
      throw new Error(`Failed to create evaluation: ${error.message}`);
    }
  },

  updateEvaluationScores: async (evaluation_id, scores) => {
    try {
      const url = `${getServiceUrl('aiEvaluation')}/evaluations/${evaluation_id}/scores`;
      console.log(`[aiEvaluationService] Updating scores: ${url}`);
      const response = await fetch(url, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(scores)
      });
      if (!response.ok) {
        throw new Error(`HTTP ${response.status}`);
      }
      return await response.json();
    } catch (error) {
      console.error('[aiEvaluationService] Error updating evaluation scores:', error.message);
      throw new Error(`Failed to update evaluation scores: ${error.message}`);
    }
  }
};

// ===== Casting Management Service =====
export const castingManagementService = {
  getCallback: async (callback_id) => {
    try {
      const url = `${getServiceUrl('castingManagement')}/callbacks/${callback_id}`;
      console.log(`[castingManagementService] Calling: ${url}`);
      const response = await fetch(url);
      if (response.status === 404) return null;
      return await response.json();
    } catch (error) {
      console.error('[castingManagementService] Error getting callback:', error.message);
      return null;
    }
  },

  sendCallback: async (audition_id, director_id, actor_id, script_content, script_url) => {
    try {
      const url = `${getServiceUrl('castingManagement')}/callbacks`;
      console.log(`[castingManagementService] Sending callback: ${url}`);
      const response = await fetch(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ audition_id, director_id, actor_id, script_content, script_url })
      });
      if (!response.ok) {
        throw new Error(`HTTP ${response.status}`);
      }
      return await response.json();
    } catch (error) {
      console.error('[castingManagementService] Error sending callback:', error.message);
      throw new Error(`Failed to send callback: ${error.message}`);
    }
  }
};

// ===== Notification Service =====
export const notificationService = {
  sendNotification: async (user_id, notificationType, title, message, relatedId = null) => {
    try {
      const url = `${getServiceUrl('notification')}/notifications`;
      console.log(`[notificationService] Sending notification: ${url}`);
      const response = await fetch(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ 
          user_id, 
          notification_type: notificationType, 
          title, 
          message, 
          related_id: relatedId 
        })
      });
      if (!response.ok) {
        throw new Error(`HTTP ${response.status}`);
      }
      return await response.json();
    } catch (error) {
      console.error('[notificationService] Error sending notification:', error.message);
      // Don't throw - notifications are not critical
      return null;
    }
  },

  getNotifications: async (user_id) => {
    try {
      const url = `${getServiceUrl('notification')}/notifications/users/${user_id}/notifications`;
      console.log(`[notificationService] Getting notifications: ${url}`);
      const response = await fetch(url);
      if (response.status === 404) return [];
      return await response.json();
    } catch (error) {
      console.error('[notificationService] Error getting notifications:', error.message);
      return [];
    }
  }
};

// ===== Audition Training Service =====
export const auditionTrainingService = {
  getSession: async (session_id) => {
    try {
      const url = `${getServiceUrl('auditionTraining')}/sessions/${session_id}`;
      console.log(`[auditionTrainingService] Calling: ${url}`);
      const response = await fetch(url);
      if (response.status === 404) return null;
      return await response.json();
    } catch (error) {
      console.error('[auditionTrainingService] Error getting training session:', error.message);
      return null;
    }
  },

  startTrainingSession: async (actor_id, media_id) => {
    try {
      const url = `${getServiceUrl('auditionTraining')}/sessions`;
      console.log(`[auditionTrainingService] Starting session: ${url}`);
      const response = await fetch(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ actor_id, media_id })
      });
      if (!response.ok) {
        throw new Error(`HTTP ${response.status}`);
      }
      return await response.json();
    } catch (error) {
      console.error('[auditionTrainingService] Error starting training session:', error.message);
      throw new Error(`Failed to start training session: ${error.message}`);
    }
  }
};
