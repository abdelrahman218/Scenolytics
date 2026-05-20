/// Formats an instant for MariaDB/MySQL `DATETIME` columns.
///
/// MySQL rejects ISO-8601 strings like `2026-05-29T11:20:00.000Z`; it expects
/// `YYYY-MM-DD HH:MM:SS` with no `T` or timezone suffix.
///
/// Uses UTC components so behavior matches [DateTime.toUtc] + ISO from the web
/// app (same instant as before; only the string shape changes).
String formatDateTimeForMysqlUtc(DateTime dt) {
  final u = dt.toUtc();
  String p2(int n) => n.toString().padLeft(2, '0');
  return '${u.year}-${p2(u.month)}-${p2(u.day)} '
      '${p2(u.hour)}:${p2(u.minute)}:${p2(u.second)}';
}
