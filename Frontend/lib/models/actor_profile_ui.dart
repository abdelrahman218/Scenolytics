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
    final fromColumn =
        stringFromMap(json, const ['display_name', 'displayName']);
    String? displayName;
    if (fromColumn != null && fromColumn.isNotEmpty) {
      displayName =
          fromColumn.length > 56 ? '${fromColumn.substring(0, 53)}…' : fromColumn;
    } else {
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
