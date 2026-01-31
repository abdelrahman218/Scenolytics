export const validateActorProfile = (profile) => {
  const errors = [];

  if (!profile.user_id) {
    errors.push('user_id is required');
  }
  if (profile.age && (profile.age < 0 || profile.age > 150)) {
    errors.push('Age must be between 0 and 150');
  }
  if (profile.height_cm && (profile.height_cm < 50 || profile.height_cm > 300)) {
    errors.push('Height must be realistic');
  }

  return {
    isValid: errors.length === 0,
    errors
  };
};

export const validateDirectorProfile = (profile) => {
  const errors = [];

  if (!profile.user_id) {
    errors.push('user_id is required');
  }
  if (profile.company_name && profile.company_name.length < 2) {
    errors.push('Company name must be at least 2 characters');
  }

  return {
    isValid: errors.length === 0,
    errors
  };
};
