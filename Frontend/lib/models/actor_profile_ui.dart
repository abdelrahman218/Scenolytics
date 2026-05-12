/// Actor-facing profile fields from User Management (`GET /api/v1/actors/:id/profile`).
class ActorProfileUi {
  const ActorProfileUi({
    this.displayName,
    this.age,
    this.portfolioUrl,
  });

  /// From API `display_name`, else first line of [bio].
  final String? displayName;
  final int? age;
  final String? portfolioUrl;

  static final RegExp _uuidLike = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  static bool _looksLikeUuid(String s) => _uuidLike.hasMatch(s.trim());

  /// Case-insensitive key read (MySQL / gateways may vary casing).
  static String? _ciString(Map<String, dynamic> json, List<String> keys) {
    final lower = <String, dynamic>{
      for (final e in json.entries) e.key.toString().toLowerCase(): e.value,
    };
    for (final key in keys) {
      final v = lower[key.toLowerCase()];
      if (v == null) continue;
      final s = v.toString().trim();
      if (s.isNotEmpty) return s;
    }
    return null;
  }

  /// Merge common wrapper objects so display fields are visible at top level.
  static Map<String, dynamic> _flattenProfileJson(Map<String, dynamic> json) {
    final out = Map<String, dynamic>.from(json);
    for (final key in const [
      'profile',
      'data',
      'actor',
      'actor_profile',
      'actorProfile',
      'result',
      'user',
    ]) {
      final v = json[key];
      if (v is Map) {
        out.addAll(v.map((k, val) => MapEntry(k.toString(), val)));
      }
    }
    return out;
  }

  static ActorProfileUi fromUserManagementJson(Map<String, dynamic> json) {
    final flat = _flattenProfileJson(json);

    String? fromNames() {
      const keys = <String>[
        'display_name',
        'displayName',
        'full_name',
        'fullName',
        'username',
        'userName',
        'name',
      ];
      for (final key in keys) {
        final s = _ciString(flat, [key]);
        if (s == null || s.isEmpty) continue;
        if (key == 'name' && _looksLikeUuid(s)) continue;
        return s.length > 56 ? '${s.substring(0, 53)}…' : s;
      }
      return null;
    }

    String? displayName = fromNames();
    if (displayName == null || displayName.isEmpty) {
      final first = _ciString(flat, const ['first_name', 'firstName']);
      final last = _ciString(flat, const ['last_name', 'lastName']);
      final combined = [first, last]
          .whereType<String>()
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .join(' ');
      if (combined.isNotEmpty) {
        displayName = combined.length > 56
            ? '${combined.substring(0, 53)}…'
            : combined;
      }
    }
    if (displayName == null || displayName.isEmpty) {
      final bio = _ciString(flat, const ['bio']) ?? '';
      if (bio.isNotEmpty) {
        final line = bio.split(RegExp(r'[\r\n]+')).first.trim();
        if (line.isNotEmpty) {
          displayName =
              line.length > 56 ? '${line.substring(0, 53)}…' : line;
        }
      }
    }

    int? age;
    Object? ageVal;
    for (final e in flat.entries) {
      if (e.key.toLowerCase() == 'age') {
        ageVal = e.value;
        break;
      }
    }
    if (ageVal is int) {
      age = ageVal;
    } else if (ageVal is num) {
      age = ageVal.round();
    } else if (ageVal is String) {
      age = int.tryParse(ageVal);
    }

    final portfolio = _ciString(flat, const ['portfolio_url', 'portfolioUrl']);
    return ActorProfileUi(
      displayName: displayName,
      age: age,
      portfolioUrl: (portfolio == null || portfolio.isEmpty) ? null : portfolio,
    );
  }
}
