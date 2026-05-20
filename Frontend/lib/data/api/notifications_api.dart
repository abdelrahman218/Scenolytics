import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/app_notification.dart';
import '../models/notification_preferences.dart';
import 'casting_api.dart';

class NotificationsApi {
  NotificationsApi({
    required String baseUrl,
    http.Client? client,
  })  : _baseUri = Uri.parse(baseUrl),
        _client = client ?? http.Client();

  final Uri _baseUri;
  final http.Client _client;

  Uri _uri(String path) => _baseUri.resolve(path);

  Map<String, String> _headers(String token) => <String, String>{
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };

  Future<List<AppNotification>> fetchNotifications({
    required String token,
  }) async {
    final response = await _client.get(
      _uri('/api/v1/notifications/'),
      headers: _headers(token),
    );

    final body = _decodeJson(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        body['message']?.toString() ??
            'Unable to load notifications (${response.statusCode}).',
        statusCode: response.statusCode,
        responseBody: response.body,
      );
    }

    final list = body['notifications'];
    if (list is! List<dynamic>) {
      return [];
    }

    final out = <AppNotification>[];
    for (final item in list) {
      final map = item is Map<String, dynamic>
          ? item
          : (item != null ? Map<String, dynamic>.from(item as Map) : null);
      if (map != null && map['id'] != null) {
        try {
          out.add(AppNotification.fromJson(map));
        } catch (_) {
          // Ignore malformed rows; keep UX responsive.
        }
      }
    }
    return out;
  }

  Future<NotificationPreferences> fetchPreferences({
    required String token,
  }) async {
    final response = await _client.get(
      _uri('/api/v1/notifications/preferences'),
      headers: _headers(token),
    );

    final body = _decodeJson(response);
    if (response.statusCode < 200 || response.statusCode >= 300 || body.isEmpty) {
      throw ApiException(
        body['message']?.toString() ??
            'Unable to load notification preferences (${response.statusCode}).',
        statusCode: response.statusCode,
        responseBody: response.body,
      );
    }

    return NotificationPreferences.fromJson(body);
  }

  Future<NotificationPreferences> updatePreferences({
    required String token,
    required NotificationPreferences preferences,
  }) async {
    final response = await _client.patch(
      _uri('/api/v1/notifications/preferences'),
      headers: _headers(token),
      body: jsonEncode(preferences.toPatchBodySendingStrings()),
    );

    final body = _decodeJson(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        body['message']?.toString() ??
            'Unable to save notification preferences (${response.statusCode}).',
        statusCode: response.statusCode,
        responseBody: response.body,
      );
    }

    return NotificationPreferences.fromJson(body);
  }

  Future<AppNotification> markAsRead({
    required String token,
    required String notificationId,
  }) async {
    final response = await _client.patch(
      _uri('/api/v1/notifications/$notificationId/read'),
      headers: _headers(token),
      body: '{}',
    );

    final body = _decodeJson(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        body['message']?.toString() ??
            'Unable to update notification (${response.statusCode}).',
        statusCode: response.statusCode,
        responseBody: response.body,
      );
    }

    return AppNotification.fromJson(body);
  }

  Map<String, dynamic> _decodeJson(http.Response response) {
    final raw = response.body.trim();
    if (raw.isEmpty) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return <String, dynamic>{};
  }

  void close() => _client.close();
}
