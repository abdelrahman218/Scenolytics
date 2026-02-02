import { createClient } from 'redis';

let client = null;

const REDIS_URL = process.env.REDIS_URL || 'redis://localhost:6379';

/**
 * Connect to Redis
 */
export const connectRedis = async () => {
  try {
    if (client && client.isOpen) {
      console.log('Redis already connected');
      return client;
    }

    client = createClient({ url: REDIS_URL });

    client.on('error', (err) => {
      console.error('Redis connection error:', err);
    });

    await client.connect();
    console.log('Connected to Redis');
    return client;
  } catch (error) {
    console.error('Failed to connect to Redis:', error);
    throw error;
  }
};

/**
 * Get or create Redis client
 */
export const getRedisClient = async () => {
  if (!client || !client.isOpen) {
    await connectRedis();
  }
  return client;
};

/**
 * Get value from cache
 */
export const getCacheValue = async (key) => {
  try {
    const redisClient = await getRedisClient();
    const value = await redisClient.get(key);
    return value ? JSON.parse(value) : null;
  } catch (error) {
    console.error(`Failed to get cache value for key ${key}:`, error);
    return null;
  }
};

/**
 * Set value in cache with TTL (in seconds)
 */
export const setCacheValue = async (key, value, ttl = 3600) => {
  try {
    const redisClient = await getRedisClient();
    await redisClient.setEx(key, ttl, JSON.stringify(value));
    console.log(`Cache set for key ${key} with TTL ${ttl}s`);
  } catch (error) {
    console.error(`Failed to set cache value for key ${key}:`, error);
    throw error;
  }
};

/**
 * Delete value from cache
 */
export const deleteCacheValue = async (key) => {
  try {
    const redisClient = await getRedisClient();
    await redisClient.del(key);
    console.log(`Cache deleted for key ${key}`);
  } catch (error) {
    console.error(`Failed to delete cache value for key ${key}:`, error);
  }
};

/**
 * Clear cache by pattern
 */
export const clearCacheByPattern = async (pattern) => {
  try {
    const redisClient = await getRedisClient();
    const keys = await redisClient.keys(pattern);
    if (keys.length > 0) {
      await redisClient.del(keys);
      console.log(`Cleared ${keys.length} cache entries matching pattern ${pattern}`);
    }
  } catch (error) {
    console.error(`Failed to clear cache by pattern ${pattern}:`, error);
  }
};

/**
 * Increment counter in cache
 */
export const incrementCounter = async (key, ttl = 3600) => {
  try {
    const redisClient = await getRedisClient();
    const value = await redisClient.incr(key);
    
    // Set TTL if this is the first increment
    if (value === 1) {
      await redisClient.expire(key, ttl);
    }
    
    return value;
  } catch (error) {
    console.error(`Failed to increment counter ${key}:`, error);
    throw error;
  }
};

/**
 * Add job to queue
 */
export const addToQueue = async (queueName, job) => {
  try {
    const redisClient = await getRedisClient();
    await redisClient.rPush(queueName, JSON.stringify(job));
    console.log(`Job added to queue ${queueName}`);
  } catch (error) {
    console.error(`Failed to add job to queue ${queueName}:`, error);
    throw error;
  }
};

/**
 * Get next job from queue
 */
export const getFromQueue = async (queueName) => {
  try {
    const redisClient = await getRedisClient();
    const job = await redisClient.lPop(queueName);
    return job ? JSON.parse(job) : null;
  } catch (error) {
    console.error(`Failed to get job from queue ${queueName}:`, error);
    return null;
  }
};

/**
 * Get queue length
 */
export const getQueueLength = async (queueName) => {
  try {
    const redisClient = await getRedisClient();
    return await redisClient.lLen(queueName);
  } catch (error) {
    console.error(`Failed to get queue length for ${queueName}:`, error);
    return 0;
  }
};

/**
 * Close Redis connection
 */
export const closeRedis = async () => {
  try {
    if (client && client.isOpen) {
      await client.quit();
      console.log('Redis connection closed');
    }
  } catch (error) {
    console.error('Error closing Redis connection:', error);
  }
};
