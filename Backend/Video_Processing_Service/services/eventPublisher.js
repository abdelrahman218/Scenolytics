/**
 * Service for publishing video processing events to RabbitMQ
 * and managing video processing jobs with Redis caching
 */

import { publishMessage, EXCHANGES, ROUTING_KEYS } from '../utils/rabbitmq.js';
import { setCacheValue, getCacheValue, addToQueue, getFromQueue, deleteCacheValue } from '../utils/redis.js';

export const publishVideoUploaded = async (videoData) => {
  try {
    await publishMessage(
      EXCHANGES.VIDEOS,
      ROUTING_KEYS.VIDEO_UPLOADED,
      {
        eventType: 'VIDEO_UPLOADED',
        timestamp: new Date(),
        data: videoData
      }
    );
  } catch (error) {
    console.error('Error publishing video uploaded event:', error);
    throw error;
  }
};

export const publishVideoProcessingStarted = async (jobData) => {
  try {
    await publishMessage(
      EXCHANGES.VIDEOS,
      ROUTING_KEYS.VIDEO_PROCESSING_STARTED,
      {
        eventType: 'VIDEO_PROCESSING_STARTED',
        timestamp: new Date(),
        data: jobData
      }
    );
  } catch (error) {
    console.error('Error publishing video processing started event:', error);
    throw error;
  }
};

export const publishVideoProcessingCompleted = async (jobData) => {
  try {
    await publishMessage(
      EXCHANGES.VIDEOS,
      ROUTING_KEYS.VIDEO_PROCESSING_COMPLETED,
      {
        eventType: 'VIDEO_PROCESSING_COMPLETED',
        timestamp: new Date(),
        data: jobData
      }
    );
  } catch (error) {
    console.error('Error publishing video processing completed event:', error);
    throw error;
  }
};

/**
 * Cache video metadata
 */
export const cacheVideoMetadata = async (videoId, metadata, ttl = 3600) => {
  try {
    await setCacheValue(`video:${videoId}:metadata`, metadata, ttl);
  } catch (error) {
    console.error('Error caching video metadata:', error);
  }
};

/**
 * Get cached video metadata
 */
export const getCachedVideoMetadata = async (videoId) => {
  try {
    return await getCacheValue(`video:${videoId}:metadata`);
  } catch (error) {
    console.error('Error retrieving cached video metadata:', error);
    return null;
  }
};

/**
 * Add video processing job to queue
 */
export const queueVideoProcessingJob = async (jobData) => {
  try {
    await addToQueue('video_processing_queue', jobData);
  } catch (error) {
    console.error('Error queuing video processing job:', error);
    throw error;
  }
};

/**
 * Get next video processing job from queue
 */
export const getNextVideoProcessingJob = async () => {
  try {
    return await getFromQueue('video_processing_queue');
  } catch (error) {
    console.error('Error getting next video processing job:', error);
    return null;
  }
};

/**
 * Cache video processing status
 */
export const cacheVideoProcessingStatus = async (jobId, status, ttl = 86400) => {
  try {
    await setCacheValue(`job:${jobId}:status`, status, ttl);
  } catch (error) {
    console.error('Error caching video processing status:', error);
  }
};

/**
 * Get cached video processing status
 */
export const getCachedVideoProcessingStatus = async (jobId) => {
  try {
    return await getCacheValue(`job:${jobId}:status`);
  } catch (error) {
    console.error('Error retrieving cached video processing status:', error);
    return null;
  }
};

/**
 * Clear video cache
 */
export const clearVideoCache = async (videoId) => {
  try {
    await deleteCacheValue(`video:${videoId}:metadata`);
  } catch (error) {
    console.error('Error clearing video cache:', error);
  }
};
