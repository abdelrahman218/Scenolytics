import { v4 as uuidv4 } from 'uuid';
import ProcessingJob from '../models/processingJob.js';

export const createProcessingJob = async (mediaId, jobType, priority = 5) => {
  try {
    const jobId = uuidv4();
    const job = await ProcessingJob.create({
      id: jobId,
      media_id: mediaId,
      job_type: jobType,
      status: 'queued',
      priority
    });

    return {
      id: jobId,
      media_id: mediaId,
      job_type: jobType,
      status: 'queued',
      priority
    };
  } catch (error) {
    throw new Error(`Failed to create processing job: ${error.message}`);
  }
};

export const getJobStatus = async (jobId) => {
  try {
    const job = await ProcessingJob.findById(jobId);
    if (!job) {
      throw new Error('Job not found');
    }
    return job;
  } catch (error) {
    throw new Error(`Failed to retrieve job status: ${error.message}`);
  }
};

export const getMediaJobs = async (mediaId) => {
  try {
    const jobs = await ProcessingJob.findByMediaId(mediaId);
    return jobs;
  } catch (error) {
    throw new Error(`Failed to retrieve media jobs: ${error.message}`);
  }
};

export const updateJobStatus = async (jobId, status, result = null, errorMessage = null) => {
  try {
    await ProcessingJob.updateStatus(jobId, status, result, errorMessage);
    const updatedJob = await ProcessingJob.findById(jobId);
    return updatedJob;
  } catch (error) {
    throw new Error(`Failed to update job status: ${error.message}`);
  }
};

export const getQueuedJobs = async () => {
  try {
    const jobs = await ProcessingJob.findByStatus('queued');
    return jobs;
  } catch (error) {
    throw new Error(`Failed to retrieve queued jobs: ${error.message}`);
  }
};
