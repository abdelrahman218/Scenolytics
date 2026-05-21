import 'actor_profile_ui.dart';

/// Read-only actor profile for director-facing detail views.
class ActorProfileDetails {
  const ActorProfileDetails({
    this.displayName,
    this.bio,
    this.age,
    this.heightCm,
    this.gender,
    this.ethnicity,
    this.bodyType,
    this.personalityTraits = const [],
    this.genres = const [],
    this.experienceYears,
    this.portfolioUrl,
  });

  final String? displayName;
  final String? bio;
  final int? age;
  final int? heightCm;
  final String? gender;
  final String? ethnicity;
  final String? bodyType;
  final List<String> personalityTraits;
  final List<String> genres;
  final int? experienceYears;
  final String? portfolioUrl;

  factory ActorProfileDetails.fromMap(Map<String, dynamic>? raw) {
    if (raw == null || raw.isEmpty) {
      return const ActorProfileDetails();
    }
    final flat = ActorProfileUi.fromUserManagementJson(raw);
    final map = _flatten(raw);

    return ActorProfileDetails(
      displayName: flat.displayName,
      bio: _str(map, const ['bio']),
      age: flat.age ?? _int(map, const ['age']),
      heightCm: _int(map, const ['height_cm', 'heightCm']),
      gender: _str(map, const ['gender']),
      ethnicity: _str(map, const ['ethnicity']),
      bodyType: _str(map, const ['body_type', 'bodyType']),
      personalityTraits: _csv(map['personality_traits'] ?? map['personalityTraits']),
      genres: _csv(map['genres']),
      experienceYears:
          _int(map, const ['experience_years', 'experienceYears']),
      portfolioUrl: flat.portfolioUrl ??
          _str(map, const ['portfolio_url', 'portfolioUrl']),
    );
  }

  bool get hasProfileContent =>
      (displayName?.trim().isNotEmpty ?? false) ||
      (bio?.trim().isNotEmpty ?? false) ||
      age != null ||
      heightCm != null ||
      (gender?.trim().isNotEmpty ?? false) ||
      (ethnicity?.trim().isNotEmpty ?? false) ||
      (bodyType?.trim().isNotEmpty ?? false) ||
      personalityTraits.isNotEmpty ||
      genres.isNotEmpty ||
      experienceYears != null ||
      (portfolioUrl?.trim().isNotEmpty ?? false);

  static Map<String, dynamic> _flatten(Map<String, dynamic> json) {
    final out = Map<String, dynamic>.from(json);
    for (final key in const [
      'profile',
      'data',
      'actor',
      'actor_profile',
      'actorProfile',
    ]) {
      final v = json[key];
      if (v is Map) {
        out.addAll(v.map((k, val) => MapEntry(k.toString(), val)));
      }
    }
    return out;
  }

  static String? _str(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final v = json[key];
      if (v == null) continue;
      final s = v.toString().trim();
      if (s.isNotEmpty) return s;
    }
    return null;
  }

  static int? _int(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final v = json[key];
      if (v is int) return v;
      if (v is num) return v.round();
      if (v is String) {
        final n = int.tryParse(v.trim());
        if (n != null) return n;
      }
    }
    return null;
  }

  static List<String> _csv(Object? v) {
    if (v == null) return const [];
    if (v is List) {
      return v
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    if (v is String) {
      return v
          .split(RegExp(r'[,;]'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return const [];
  }
}
