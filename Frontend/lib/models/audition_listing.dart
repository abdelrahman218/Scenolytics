/// How the signed-in actor is related to this audition.
enum AuditionRelationship {
  /// Director invited the actor; they have not submitted yet.
  invited,

  /// Actor already uploaded a submission for this audition.
  submitted,
}

class AuditionListing {
  const AuditionListing({
    required this.id,
    required this.directorId,
    required this.title,
    required this.description,
    required this.type,
    required this.minAge,
    required this.maxAge,
    required this.gender,
    required this.ethnicity,
    required this.bodyType,
    this.minHeightCm,
    this.maxHeightCm,
    this.createdAt,
    this.directorDisplayName,
    this.relationship,
  });

  final String id;
  final String directorId;
  final String title;
  final String description;

  /// 'Audio' or 'Video' — mirrors backend ENUM.
  final String type;
  final int minAge;
  final int maxAge;

  /// 'Male' | 'Female' | 'Both'.
  final String gender;

  /// 'White' | 'Black' | 'Asian' | 'Arab' | 'Any'.
  final String ethnicity;

  /// 'Slim' | 'Athletic' | 'Average' | 'Heavyset' | 'Any'.
  final String bodyType;
  final int? minHeightCm;
  final int? maxHeightCm;
  final DateTime? createdAt;

  /// Resolved from `/api/v1/directors/:user_id/profile` when available.
  final String? directorDisplayName;

  /// Optional relationship between the signed-in actor and this audition.
  final AuditionRelationship? relationship;

  bool get isInvited => relationship == AuditionRelationship.invited;
  bool get isSubmitted => relationship == AuditionRelationship.submitted;

  bool get hasHeightRequirement =>
      (minHeightCm != null && minHeightCm! > 0) ||
      (maxHeightCm != null && maxHeightCm! > 0);

  String get heightLabel {
    final lo = minHeightCm;
    final hi = maxHeightCm;
    if (lo != null && hi != null && lo > 0 && hi > 0) return '$lo–$hi cm';
    if (lo != null && lo > 0) return '≥ $lo cm';
    if (hi != null && hi > 0) return '≤ $hi cm';
    return 'Any height';
  }

  String get ageLabel => '$minAge–$maxAge';

  AuditionListing copyWith({
    String? directorDisplayName,
    AuditionRelationship? relationship,
  }) {
    return AuditionListing(
      id: id,
      directorId: directorId,
      title: title,
      description: description,
      type: type,
      minAge: minAge,
      maxAge: maxAge,
      gender: gender,
      ethnicity: ethnicity,
      bodyType: bodyType,
      minHeightCm: minHeightCm,
      maxHeightCm: maxHeightCm,
      createdAt: createdAt,
      directorDisplayName: directorDisplayName ?? this.directorDisplayName,
      relationship: relationship ?? this.relationship,
    );
  }

  /// Lenient parser — tolerates missing or stringified numeric fields.
  factory AuditionListing.fromJson(Map<String, dynamic> json) {
    int parseInt(Object? v, {int fallback = 0}) {
      if (v == null) return fallback;
      if (v is int) return v;
      if (v is num) return v.toInt();
      final s = v.toString().trim();
      return int.tryParse(s) ?? fallback;
    }

    int? parseNullableInt(Object? v) {
      if (v == null) return null;
      if (v is int) return v;
      if (v is num) return v.toInt();
      final s = v.toString().trim();
      if (s.isEmpty) return null;
      return int.tryParse(s);
    }

    return AuditionListing(
      id: json['id']?.toString() ?? '',
      directorId: json['director_id']?.toString() ?? '',
      title: (json['title']?.toString() ?? '').trim(),
      description: (json['description']?.toString() ?? '').trim(),
      type: (json['type']?.toString() ?? '').trim(),
      minAge: parseInt(json['candidate_min_age']),
      maxAge: parseInt(json['candidate_max_age']),
      gender: (json['candidate_gender']?.toString() ?? 'Both').trim(),
      ethnicity: (json['candidate_ethnicity']?.toString() ?? 'Any').trim(),
      bodyType: (json['candidate_body_type']?.toString() ?? 'Any').trim(),
      minHeightCm: parseNullableInt(json['candidate_min_height_cm']),
      maxHeightCm: parseNullableInt(json['candidate_max_height_cm']),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
    );
  }
}
