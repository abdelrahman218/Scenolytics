const MAX_FILE_SIZE = 500 * 1024 * 1024; // 500MB
const ALLOWED_AUDIO_TYPES = ['audio/mpeg', 'audio/wav', 'audio/ogg', 'audio/mp4'];
const ALLOWED_VIDEO_TYPES = ['video/mp4', 'video/mpeg', 'video/quicktime', 'video/webm'];

export const validateMediaUpload = (file) => {
  const errors = [];

  if (!file) {
    errors.push('No file provided');
  } else {
    if (file.size > MAX_FILE_SIZE) {
      errors.push(`File size exceeds maximum limit of 500MB`);
    }

    const mimeType = file.mimetype;
    const isAudio = ALLOWED_AUDIO_TYPES.includes(mimeType);
    const isVideo = ALLOWED_VIDEO_TYPES.includes(mimeType);

    if (!isAudio && !isVideo) {
      errors.push(`Invalid file type. Allowed: Audio (${ALLOWED_AUDIO_TYPES.join(', ')}) or Video (${ALLOWED_VIDEO_TYPES.join(', ')})`);
    }
  }

  return {
    isValid: errors.length === 0,
    errors
  };
};

export const getMediaType = (mimeType) => {
  if (ALLOWED_AUDIO_TYPES.includes(mimeType)) return 'audio';
  if (ALLOWED_VIDEO_TYPES.includes(mimeType)) return 'video';
  return null;
};
