// ==================== HELPER VALIDATORS ====================

/**
 * Validates that all required fields are present in request body
 */
export const checkRequiredFields = (fields) => {
  return (req, res, next) => {
    const missingFields = fields.filter(field => !req.body[field]);
    if (missingFields.length > 0) {
      return res.status(400).json({ message: `Missing required fields: ${missingFields.join(', ')}` });
    }
    next();
  };
};

/**
 * Validates that field values are within allowed options
 */
export const checkValidValues = (fieldsValues) => {
  return (req, res, next) => {
    for (const [field, values] of Object.entries(fieldsValues)) {
      if (req.body[field] && !values.includes(req.body[field])) {
        return res.status(400).json({ message: `Invalid value for ${field}: ${req.body[field]}. Allowed: ${values.join(', ')}` });
      }
    }
    next();
  };
};

// ==================== ACTOR PROFILE VALIDATORS ====================

// Valid personality trait options
export const VALID_PERSONALITY_TRAITS = [
  'Outgoing',
  'Introverted',
  'Creative',
  'Analytical',
  'Emotional',
  'Calm',
  'Energetic',
  'Spontaneous',
  'Thoughtful',
  'Humorous',
  'Serious',
  'Passionate',
  'Reserved',
  'Charismatic',
  'Friendly',
  'Intense'
];

// Actor required fields
export const validateActorProfileRequiredFields = checkRequiredFields(['user_id']);

// Actor enum validations
export const validateActorProfileValues = checkValidValues({
  gender: ['Male', 'Female'],
  ethnicity: ['White', 'Black', 'Asian', 'Arab', 'Any'],
  bodyType: ['Slim', 'Athletic', 'Average', 'Heavyset','Any']
});

/**
 * Validates actor profile data for valid values and ranges
 */
export const validateActorProfile = (profile) => {
  const errors = [];

  if (!profile.user_id) {
    errors.push('user_id is required');
  }
  
  // Age validation
  if (profile.age !== undefined && profile.age !== null) {
    if (profile.age < 0 || profile.age > 150) {
      errors.push('Age must be between 0 and 150');
    }
  }
  
  // Height validation
  if (profile.height_cm !== undefined && profile.height_cm !== null) {
    if (profile.height_cm < 50 || profile.height_cm > 300) {
      errors.push('Height must be between 50cm and 300cm');
    }
  }
  
  // Weight validation
  if (profile.weight_kg !== undefined && profile.weight_kg !== null) {
    if (profile.weight_kg < 20 || profile.weight_kg > 500) {
      errors.push('Weight must be between 20kg and 500kg');
    }
  }
  
  // Gender validation
  if (profile.gender && !['Male', 'Female', 'Other'].includes(profile.gender)) {
    errors.push('Gender must be Male, Female, or Other');
  }
  
  // Ethnicity validation
  if (profile.ethnicity && !['White', 'Black', 'Asian', 'Arab', 'Any'].includes(profile.ethnicity)) {
    errors.push('Invalid ethnicity value');
  }
  
  // Body type validation
  if (profile.bodyType && !['Slim', 'Athletic', 'Average', 'Heavyset'].includes(profile.bodyType)) {
    errors.push('Invalid body type value');
  }
  
  // Bio length validation
  if (profile.bio && profile.bio.length > 1000) {
    errors.push('Bio must be 1000 characters or less');
  }
  
  // Personality traits validation
  if (profile.personality_traits !== undefined && profile.personality_traits !== null) {
    if (!Array.isArray(profile.personality_traits)) {
      errors.push('Personality traits must be an array');
    } else if (profile.personality_traits.length > 0) {
      // Validate each trait is a non-empty string and valid enum value
      const invalidTraits = profile.personality_traits.filter(trait => 
        typeof trait !== 'string' || trait.trim() === '' || !VALID_PERSONALITY_TRAITS.includes(trait)
      );
      if (invalidTraits.length > 0) {
        errors.push(`Invalid personality traits. Valid options: ${VALID_PERSONALITY_TRAITS.join(', ')}`);
      }
    }
  }

  return {
    isValid: errors.length === 0,
    errors
  };
};

// ==================== DIRECTOR PROFILE VALIDATORS ====================

// Director required fields
export const validateDirectorProfileRequiredFields = checkRequiredFields(['user_id']);

/**
 * Validates director profile data for valid values and ranges
 */
export const validateDirectorProfile = (profile) => {
  const errors = [];

  if (!profile.user_id) {
    errors.push('user_id is required');
  }
  
  // Company name validation
  if (profile.companyName && profile.companyName.length < 2) {
    errors.push('Company name must be at least 2 characters');
  }
  
  if (profile.companyName && profile.companyName.length > 200) {
    errors.push('Company name must be 200 characters or less');
  }
  
  // Years of experience validation
  if (profile.yearsOfExperience !== undefined && profile.yearsOfExperience !== null) {
    if (profile.yearsOfExperience < 0 || profile.yearsOfExperience > 70) {
      errors.push('Years of experience must be between 0 and 70');
    }
  }
  
  // Bio length validation
  if (profile.bio && profile.bio.length > 1000) {
    errors.push('Bio must be 1000 characters or less');
  }

  return {
    isValid: errors.length === 0,
    errors
  };
};
