String formatDateTimeForMysqlUtc(DateTime dt) {
  final u = dt.toUtc();
  String p2(int n) => n.toString().padLeft(2, '0');
  return '${u.year}-${p2(u.month)}-${p2(u.day)} '
      '${p2(u.hour)}:${p2(u.minute)}:${p2(u.second)}';
}
