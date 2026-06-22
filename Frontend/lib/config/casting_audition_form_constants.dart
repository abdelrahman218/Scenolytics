// Matches `Backend/Casting_Management_Service/create_tables.sql` ENUMs.

import 'package:flutter/material.dart';

// Emotions a director can assign to a script sentence. `fearful`, `disgust`
// and `neutral` are intentionally omitted from the picker to reduce confusion,
// even though the backend ENUM still accepts them (frontend-only narrowing).
const List<String> kAuditionScriptEmotions = <String>[
  'calm',
  'happy',
  'sad',
  'angry',
  'surprised',
];

/// Emoji glyph per emotion. Includes emotions no longer selectable in the
/// picker (`neutral`, `fearful`, `disgust`) so legacy auditions and backend
/// evaluation data (e.g. tone segments tagged `neutral`) still render.
const Map<String, String> kAuditionEmotionEmoji = <String, String>{
  'neutral': '😐',
  'calm': '😌',
  'happy': '😄',
  'sad': '😢',
  'angry': '😠',
  'fearful': '😨',
  'disgust': '🤢',
  'surprised': '😲',
};

/// Accent hue used by the emotion pill chips (kept harmonised with the
/// Scenolytics cyan/blue theme — picked to be visually distinguishable while
/// still feeling like a single design system).
const Map<String, Color> kAuditionEmotionAccent = <String, Color>{
  'neutral': Color(0xFF6B8794),
  'calm': Color(0xFF38BDF8),
  'happy': Color(0xFFFBBF24),
  'sad': Color(0xFF5C6BC0),
  'angry': Color(0xFFEF4444),
  'fearful': Color(0xFF8B5CF6),
  'disgust': Color(0xFF10B981),
  'surprised': Color(0xFFE879F9),
};

String emotionEmoji(String backendValue) {
  return kAuditionEmotionEmoji[backendValue.trim().toLowerCase()] ?? '🎭';
}

Color emotionAccent(String backendValue) {
  return kAuditionEmotionAccent[backendValue.trim().toLowerCase()] ??
      const Color(0xFF6B8794);
}

const List<String> kAuditionMediaTypes = <String>['Audio', 'Video'];

const List<String> kAuditionGenders = <String>['Male', 'Female', 'Both'];

const List<String> kAuditionEthnicities = <String>[
  'White',
  'Black',
  'Asian',
  'Arab',
  'Any',
];

const List<String> kAuditionBodyTypes = <String>[
  'Slim',
  'Athletic',
  'Average',
  'Heavyset',
  'Any',
];

/// Maps common synonyms / labels to a *selectable* emotion. Emotions removed
/// from the picker (`neutral`, `fearful`, `disgust`) collapse to `calm` so the
/// chosen value always exists in [kAuditionScriptEmotions].
String coerceAuditionEmotion(String raw) {
  final key = raw.trim().toLowerCase();
  if (key.isEmpty) return 'calm';
  if (kAuditionScriptEmotions.contains(key)) return key;

  const synonyms = <String, String>{
    'joy': 'happy',
    'joyful': 'happy',
    'excited': 'happy',
    'mad': 'angry',
    'anger': 'angry',
    'surprise': 'surprised',
    // Removed-from-picker emotions fall back to a neutral-ish selectable value.
    'neutral': 'calm',
    'neutral_tone': 'calm',
    'fearful': 'sad',
    'scared': 'sad',
    'afraid': 'sad',
    'fear': 'sad',
    'disgust': 'angry',
    'disgusted': 'angry',
  };
  final mapped = synonyms[key];
  if (mapped != null && kAuditionScriptEmotions.contains(mapped)) {
    return mapped;
  }
  return 'calm';
}

String emotionLabelForUi(String backendValue) {
  if (backendValue.isEmpty) return backendValue;
  return '${backendValue[0].toUpperCase()}${backendValue.substring(1)}';
}

/// Friendly label with the emoji baked in, e.g. `😄 Happy`.
String emotionLabelWithEmoji(String backendValue) {
  return '${emotionEmoji(backendValue)}  ${emotionLabelForUi(backendValue)}';
}
