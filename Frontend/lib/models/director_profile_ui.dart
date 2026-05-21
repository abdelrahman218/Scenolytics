import '../utils/json_map_read.dart';

class DirectorProfileUi {
  const DirectorProfileUi({
    this.displayName,
    this.companyName,
  });

  final String? displayName;
  final String? companyName;

  static String? _truncateLabel(String value) {
    final t = value.trim();
    if (t.isEmpty) return null;
    return t.length > 56 ? '${t.substring(0, 53)}…' : t;
  }

  static DirectorProfileUi fromUserManagementJson(Map<String, dynamic> json) {
    final fromColumn =
        stringFromMap(json, const ['display_name', 'displayName']);
    String? displayName;
    if (fromColumn != null && fromColumn.isNotEmpty) {
      displayName = _truncateLabel(fromColumn);
    } else {
      final company =
          stringFromMap(json, const ['company_name', 'companyName']) ?? '';
      if (company.isNotEmpty) {
        displayName = _truncateLabel(company);
      } else {
        final bio =
            stringFromMap(json, const ['company_bio', 'companyBio']) ?? '';
        if (bio.isNotEmpty) {
          final line = bio.split(RegExp(r'[\r\n]+')).first.trim();
          if (line.isNotEmpty) {
            displayName = _truncateLabel(line);
          }
        }
      }
    }

    final rawCompany =
        stringFromMap(json, const ['company_name', 'companyName']);
    return DirectorProfileUi(
      displayName: displayName,
      companyName:
          (rawCompany == null || rawCompany.isEmpty) ? null : rawCompany,
    );
  }
}
