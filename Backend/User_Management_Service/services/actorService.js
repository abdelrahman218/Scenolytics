import { v4 as uuidv4 } from 'uuid';
import ActorProfile from '../models/actorProfile.js';
import { identityProviderService } from '../utils/serviceClient.js';

export const createActorProfile = async (user_id, profileData) => {
  try {
    // Validate user exists in Identity Provider
    const userExists = await identityProviderService.checkUserExists(user_id);
    if (!userExists) {
      throw new Error('User not found in Identity Provider');
    }

    const profileId = uuidv4();
    await ActorProfile.create({
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
    await ActorProfile.update(profile_id, updates);
    const profile = await ActorProfile.findById(profile_id);
    return profile;
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
