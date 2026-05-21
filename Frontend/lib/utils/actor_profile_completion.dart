import '../constants/profile_field_options.dart';

/// Returns true when the actor profile row has every field required by the app.
bool isActorProfileComplete(Map<String, dynamic>? profile) {
  if (profile == null || profile.isEmpty) return false;

  final flat = _flatten(profile);

  final displayName = _readString(flat, const [
    'display_name',
    'displayName',
    'name',
  ]);
  if (displayName == null || displayName.length < 2) return false;

  final age = _readInt(flat, const ['age']);
  if (age == null || age < 1 || age > 120) return false;

  final heightCm = _readInt(flat, const ['height_cm', 'heightCm']);
  if (heightCm == null || heightCm < 50 || heightCm > 300) return false;

  final gender = _readString(flat, const ['gender']);
  if (gender == null ||
      !ActorProfileOptions.genderOptions.contains(gender)) {
    return false;
  }

  final bodyType = _readString(flat, const ['body_type', 'bodyType']);
  if (bodyType == null ||
      !ActorProfileOptions.bodyTypeOptions.contains(bodyType)) {
    return false;
  }

  final ethnicity = _readString(flat, const ['ethnicity']);
  if (ethnicity == null ||
      !ActorProfileOptions.ethnicityOptions.contains(ethnicity)) {
    return false;
  }

  return true;
}

Map<String, dynamic> _flatten(Map<String, dynamic> json) {
  final out = Map<String, dynamic>.from(json);
  for (final key in const [
    'profile',
    'data',
    'actor',
    'actor_profile',
    'actorProfile',
    'result',
  ]) {
    final v = json[key];
    if (v is Map) {
      out.addAll(v.map((k, val) => MapEntry(k.toString(), val)));
    }
  }
  return out;
}

Map<String, dynamic> _lowerKeys(Map<String, dynamic> json) {
  return {
    for (final e in json.entries) e.key.toString().toLowerCase(): e.value,
  };
}

String? _readString(Map<String, dynamic> json, List<String> keys) {
  final lower = _lowerKeys(json);
  for (final key in keys) {
    final v = json[key] ?? lower[key.toLowerCase()];
    if (v == null) continue;
    final s = v.toString().trim();
    if (s.isNotEmpty) return s;
  }
  return null;
}

int? _readInt(Map<String, dynamic> json, List<String> keys) {
  final lower = _lowerKeys(json);
  for (final key in keys) {
    final v = json[key] ?? lower[key.toLowerCase()];
    if (v == null) continue;
    if (v is int) return v;
    if (v is num) return v.round();
    if (v is String) return int.tryParse(v.trim());
  }
  return null;
}
