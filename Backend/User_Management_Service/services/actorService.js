import { v4 as uuidv4 } from 'uuid';
import ActorProfile from '../models/actorProfile.js';
import { identityProviderService } from '../utils/serviceClient.js';

export const createActorProfile = async (user_id, profileData) => {
  try {
    const profileId = uuidv4();
    await ActorProfile.create({
      id: profileId,
      user_id,
      display_name: profileData.name,
      bio: profileData.bio || null,
      height_cm: profileData.height_cm || null,
      age: profileData.age,
      gender: profileData.gender,
      ethnicity: profileData.ethnicity || null,
      body_type: profileData.body_type || null,
      genres: profileData.genres || null,
      experience_years: profileData.experience_years || null,
      portfolio_url: profileData.portfolio_url || null
    });

    return {
      id: profileId,
      user_id,
      display_name: profileData.name,
      bio: profileData.bio || null,
      height_cm: profileData.height_cm || null,
      age: profileData.age,
      gender: profileData.gender,
      ethnicity: profileData.ethnicity || null,
      body_type: profileData.body_type || null,
      genres: profileData.genres || null,
      experience_years: profileData.experience_years || null,
      portfolio_url: profileData.portfolio_url || null
    };
  } catch (error) {
    throw new Error(`Failed to create actor profile: ${error.message}`);
  }
};

export const getActorProfile = async (user_id) => {
  try {
    const profile = await ActorProfile.findByUserId(user_id);
    if (!profile) {
      throw new Error('Actor profile not found');
    }
    return profile;
  } catch (error) {
    throw new Error(`Failed to retrieve actor profile: ${error.message}`);
  }
};

export const updateActorProfile = async (profile_id, updates) => {
  try {
    const existing = await ActorProfile.findById(profile_id);
    if (!existing) {
      throw new Error('Actor profile not found');
    }

    const displayName =
      updates.display_name ?? updates.name ?? existing.display_name;

    const merged = {
      display_name: displayName,
      bio: updates.bio !== undefined ? updates.bio : existing.bio,
      height_cm:
        updates.height_cm !== undefined ? updates.height_cm : existing.height_cm,
      age: updates.age !== undefined ? updates.age : existing.age,
      gender: updates.gender !== undefined ? updates.gender : existing.gender,
      ethnicity:
        updates.ethnicity !== undefined ? updates.ethnicity : existing.ethnicity,
      body_type:
        updates.body_type !== undefined ? updates.body_type : existing.body_type,
      genres: updates.genres !== undefined ? updates.genres : existing.genres,
      experience_years:
        updates.experience_years !== undefined
          ? updates.experience_years
          : existing.experience_years,
    };

    await ActorProfile.update(profile_id, merged);
    return await ActorProfile.findById(profile_id);
  } catch (error) {
    throw new Error(`Failed to update actor profile: ${error.message}`);
  }
};

export const searchActors = async (filters) => {
  try {
    const actors = await ActorProfile.searchByAttributes(filters);
    return actors;
  } catch (error) {
    throw new Error(`Failed to search actors: ${error.message}`);
  }
};

export const deleteActorProfile = async (profile_id) => {
  try {
    await ActorProfile.delete(profile_id);
    return { message: 'Actor profile deleted successfully' };
  } catch (error) {
    throw new Error(`Failed to delete actor profile: ${error.message}`);
  }
};
