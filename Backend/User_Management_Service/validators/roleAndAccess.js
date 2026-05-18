/**
 * Role-Based Access Control Validators
 * Ensures users only access endpoints for their role
 */

import jwt from 'jsonwebtoken';

const JWT_SECRET = process.env.JWT_SECRET;

/**
 * Validates that the request contains a valid JWT token and extracts user info
 */
export const validateJWTToken = (req, res, next) => {
  const authHeader = req.headers.authorization;
  
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({
      message: 'Authorization header missing or malformed'
    });
  }
  
  const token = authHeader.split(' ')[1];
  
  try {
    const decoded = jwt.verify(token, JWT_SECRET);
    req.user = decoded;
    next();
  } catch (error) {
    return res.status(401).json({
      message: 'Invalid or expired token'
    });
  }
};

/**
 * Validates that only actors can access actor-specific endpoints
 */
export const validateActorRole = (req, res, next) => {
  if (!req.user) {
    return res.status(401).json({
      message: 'User not authenticated'
    });
  }
  
  if (req.user.role !== 'actor') {
    return res.status(403).json({
      message: 'Only actors can access this endpoint'
    });
  }
  
  next();
};

/**
 * Validates that only directors can access director-specific endpoints
 */
export const validateDirectorRole = (req, res, next) => {
  if (!req.user) {
    return res.status(401).json({
      message: 'User not authenticated'
    });
  }
  
  if (req.user.role !== 'director') {
    return res.status(403).json({
      message: 'Only directors can access this endpoint'
    });
  }
  
  next();
};

/**
 * Validates that user can only view their own profile or directors can view any actor profile
 * Directors viewing profiles is allowed for casting purposes
 */
export const validateProfileAccess = (req, res, next) => {
  if (!req.user) {
    return res.status(401).json({
      message: 'User not authenticated'
    });
  }
  
  const requestedUserId = req.params.user_id;
  const isOwnProfile = req.user.user_id === requestedUserId;
  const isDirector = req.user.role === 'director';
  
  // Allow if user is viewing their own profile or if they're a director (can view actor profiles for casting)
  if (!isOwnProfile && !isDirector) {
    return res.status(403).json({
      message: 'You can only view your own profile'
    });
  }
  
  next();
};

/**
 * Validates that only the profile owner can update/delete their profile
 */
export const validateProfileOwnership = (req, res, next) => {
  if (!req.user) {
    return res.status(401).json({
      message: 'User not authenticated'
    });
  }
  
  const profileUserId = req.body.user_id || req.params.user_id;
  const isOwner = req.user.user_id === profileUserId;
  
  if (!isOwner) {
    return res.status(403).json({
      message: 'You can only manage your own profile'
    });
  }
  
  next();
};
