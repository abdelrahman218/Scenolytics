import { v4 as uuidv4 } from 'uuid';
import DirectorProfile from '../models/directorProfile.js';
import { identityProviderService } from '../utils/serviceClient.js';

export const createDirectorProfile = async (user_id, profileData) => {
  try {
    // Validate user exists in Identity Provider
    const userExists = await identityProviderService.checkUserExists(user_id);
    if (!userExists) {
      throw new Error('User not found in Identity Provider');
    }

    const profileId = uuidv4();
    await DirectorProfile.create({
      id: profileId,
      user_id,
      ...profileData
    });
    return {
      id: profileId,
      user_id,
      ...profileData
    };
  } catch (error) {
    throw new Error(`Failed to create director profile: ${error.message}`);
  }
};

export const getDirectorProfile = async (user_id) => {
  try {
    const profile = await DirectorProfile.findByUserId(user_id);
    if (!profile) {
      throw new Error('Director profile not found');
    }
    return profile;
  } catch (error) {
    throw new Error(`Failed to retrieve director profile: ${error.message}`);
  }
};

export const updateDirectorProfile = async (profile_id, updates) => {
  try {
    await DirectorProfile.update(profile_id, updates);
    const profile = await DirectorProfile.findById(profile_id);
    return profile;
  } catch (error) {
    throw new Error(`Failed to update director profile: ${error.message}`);
  }
};

export const deleteDirectorProfile = async (profile_id) => {
  try {
    await DirectorProfile.delete(profile_id);
    return { message: 'Director profile deleted successfully' };
  } catch (error) {
    throw new Error(`Failed to delete director profile: ${error.message}`);
  }
};
