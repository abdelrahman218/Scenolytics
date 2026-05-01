import '../utils/json_map_read.dart';

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

  static ActorProfileUi fromUserManagementJson(Map<String, dynamic> json) {
    String? fromNames() {
      final s = stringFromMap(
        json,
        const [
          'display_name',
          'displayName',
          'full_name',
          'fullName',
          'name',
        ],
      );
      if (s == null || s.isEmpty) {
        return null;
      }
      return s.length > 56 ? '${s.substring(0, 53)}…' : s;
    }

    String? displayName = fromNames();
    if (displayName == null || displayName.isEmpty) {
      final first = stringFromMap(json, const ['first_name', 'firstName']);
      final last = stringFromMap(json, const ['last_name', 'lastName']);
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
      final bio = stringFromMap(json, const ['bio']) ?? '';
      if (bio.isNotEmpty) {
        final line = bio.split(RegExp(r'[\r\n]+')).first.trim();
        if (line.isNotEmpty) {
          displayName =
              line.length > 56 ? '${line.substring(0, 53)}…' : line;
        }
      }
    }

    int? age;
    final rawAge = json['age'];
    if (rawAge is int) {
      age = rawAge;
    } else if (rawAge is num) {
      age = rawAge.round();
    } else if (rawAge is String) {
      age = int.tryParse(rawAge);
    }

    final portfolio =
        stringFromMap(json, const ['portfolio_url', 'portfolioUrl']);
    return ActorProfileUi(
      displayName: displayName,
      age: age,
      portfolioUrl: (portfolio == null || portfolio.isEmpty) ? null : portfolio,
    );
  }
}
