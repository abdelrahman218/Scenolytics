import 'dart:convert';

import 'json_map_read.dart';

/// Reads a stable user id from a JWT payload (no signature verification — display / routing only).
///
/// Tries `user_id` (Identity Provider), then `userId`, then OIDC-style `sub`.
String? userIdFromActorJwt(String token) {
  final trimmed = token.trim();
  if (trimmed.isEmpty) return null;
  final parts = trimmed.split('.');
  if (parts.length != 3) return null;
  var payload = parts[1];
  final mod = payload.length % 4;
  if (mod != 0) {
    payload = payload.padRight(payload.length + (4 - mod), '=');
  }
  try {
    final bytes = base64Url.decode(payload);
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map) return null;
    final json = decoded.map((k, v) => MapEntry(k.toString(), v));
    return stringFromMap(json, const ['user_id', 'userId', 'sub']);
  } catch (_) {
    return null;
  }
}
