import { v4 as uuidv4 } from 'uuid';
import path from 'path';
import fs from 'fs';
import Media from '../models/media.js';
import { identityProviderService, submissionEvaluationService } from '../utils/serviceClient.js';

export const uploadMedia = async (file, userId) => {
  try {
    // Validate user exists in Identity Provider
    const userExists = await identityProviderService.checkUserExists(userId);
    if (!userExists) {
      throw new Error('User not found in Identity Provider');
    }

    const mediaId = uuidv4();
    const fileExtension = path.extname(file.originalname);
    const fileName = `${mediaId}${fileExtension}`;
    const filePath = path.join('uploads', fileName);

    // Ensure uploads directory exists
    if (!fs.existsSync('uploads')) {
      fs.mkdirSync('uploads', { recursive: true });
    }

    // Save file
    fs.writeFileSync(filePath, file.buffer);

    // Determine media type
    const mediaType = file.mimetype.startsWith('audio') ? 'audio' : 'video';

    // Save metadata to database
    const media = await Media.create({
      id: mediaId,
      user_id: userId,
      file_name: file.originalname,
      file_path: filePath,
      file_type: mediaType,
      file_size: file.size,
      mime_type: file.mimetype,
      status: 'uploaded'
    });

    // Create evaluation job for the uploaded media
    try {
      await submissionEvaluationService.createEvaluation(mediaId);
    } catch (evalError) {
      console.warn('Failed to create evaluation job:', evalError.message);
    }

    return {
      id: mediaId,
      file_name: file.originalname,
      file_type: mediaType,
      file_size: file.size,
      status: 'uploaded'
    };
  } catch (error) {
    throw new Error(`Failed to upload media: ${error.message}`);
  }
};

export const getMediaById = async (mediaId) => {
  try {
    const media = await Media.findById(mediaId);
    if (!media) {
      throw new Error('Media not found');
    }
    return media;
  } catch (error) {
    throw new Error(`Failed to retrieve media: ${error.message}`);
  }
};

export const getUserMedia = async (userId) => {
  try {
    const media = await Media.findByUserId(userId);
    return media;
  } catch (error) {
    throw new Error(`Failed to retrieve user media: ${error.message}`);
  }
};

export const deleteMedia = async (mediaId) => {
  try {
    const media = await Media.findById(mediaId);
    if (!media) {
      throw new Error('Media not found');
    }

    // Delete file from storage
    if (fs.existsSync(media.file_path)) {
      fs.unlinkSync(media.file_path);
    }

    // Delete from database
    await Media.delete(mediaId);
    return { message: 'Media deleted successfully' };
  } catch (error) {
    throw new Error(`Failed to delete media: ${error.message}`);
  }
};
