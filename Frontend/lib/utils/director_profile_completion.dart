/// Returns true when the director profile row has every field required by the app.
bool isDirectorProfileComplete(Map<String, dynamic>? profile) {
  if (profile == null || profile.isEmpty) return false;

  final flat = _flatten(profile);

  final displayName = _readString(flat, const [
    'display_name',
    'displayName',
    'name',
  ]);
  if (displayName == null || displayName.length < 2) return false;

  final phone = _readString(flat, const ['phone']);
  if (phone == null || phone.length < 7) return false;

  final digits = phone.replaceAll(RegExp(r'[\s\-\(\)\.\+]'), '');
  if (digits.length < 7 || digits.length > 20) return false;
  if (!RegExp(r'^\+?[0-9]+$').hasMatch(digits)) return false;

  return true;
}

Map<String, dynamic> _flatten(Map<String, dynamic> json) {
  final out = Map<String, dynamic>.from(json);
  for (final key in const [
    'profile',
    'data',
    'director',
    'director_profile',
    'directorProfile',
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
