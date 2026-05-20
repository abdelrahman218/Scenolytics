import { v4 as uuidv4 } from 'uuid';
import DirectorProfile from '../models/directorProfile.js';
import { identityProviderService } from '../utils/serviceClient.js';

export const createDirectorProfile = async (user_id, profileData) => {
  try {
    const profileId = uuidv4();
    await DirectorProfile.create({
      id: profileId,
      user_id,
      display_name: profileData.name, 
      company_name: profileData.company_name || null,
      company_bio: profileData.company_bio || null,
      website: profileData.website || null,
      phone: profileData.phone || null,
      location: profileData.location || null
    });
    
    return {
      id: profileId,
      user_id,
      display_name: profileData.name,
      company_name: profileData.company_name,
      company_bio: profileData.company_bio,
      website: profileData.website,
      phone: profileData.phone,
      location: profileData.location
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

const nullIfEmpty = (value) => {
  if (value === undefined || value === null) return null;
  if (typeof value === 'string' && value.trim() === '') return null;
  return value;
};

export const updateDirectorProfile = async (profile_id, updates) => {
  try {
    const existing = await DirectorProfile.findById(profile_id);
    if (!existing) {
      throw new Error('Director profile not found');
    }

    const displayName =
      updates.display_name ?? updates.name ?? existing.display_name;

    const merged = {
      display_name: displayName,
      company_name:
        updates.company_name !== undefined
          ? nullIfEmpty(updates.company_name)
          : existing.company_name,
      company_bio:
        updates.company_bio !== undefined
          ? nullIfEmpty(updates.company_bio)
          : existing.company_bio,
      website:
        updates.website !== undefined
          ? nullIfEmpty(updates.website)
          : existing.website,
      phone:
        updates.phone !== undefined
          ? nullIfEmpty(updates.phone)
          : existing.phone,
      location:
        updates.location !== undefined
          ? nullIfEmpty(updates.location)
          : existing.location,
    };

    await DirectorProfile.update(profile_id, merged);
    return await DirectorProfile.findById(profile_id);
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
