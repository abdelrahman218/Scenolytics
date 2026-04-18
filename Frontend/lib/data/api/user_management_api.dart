import 'dart:convert';
import 'dart:developer' as developer;

import 'package:http/http.dart' as http;

/// Reads public actor profile rows from the API gateway (`/api/v1/actors/...`).
class UserManagementApi {
  UserManagementApi({
    required String baseUrl,
    http.Client? client,
  })  : _baseUri = Uri.parse(baseUrl),
        _client = client ?? http.Client();

  final Uri _baseUri;
  final http.Client _client;

  Uri _uri(String path) => _baseUri.resolve(path);

  /// Returns profile JSON or null if missing / network error.
  Future<Map<String, dynamic>?> getDirectorProfile(String userId) async {
    final trimmed = userId.trim();
    if (trimmed.isEmpty) return null;
    try {
      final response = await _client.get(
        _uri('/api/v1/directors/$trimmed/profile'),
        headers: const {'Accept': 'application/json'},
      );
      if (response.statusCode == 404) {
        _logProfileFailure('getDirectorProfile', trimmed, response);
        return null;
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        _logProfileFailure('getDirectorProfile', trimmed, response);
        return null;
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return null;
      return _unwrapProfileBody(
        decoded.map((k, v) => MapEntry(k.toString(), v)),
      );
    } catch (_) {
      return null;
    }
  }

  /// Returns profile JSON or null if missing / network error.
  Future<Map<String, dynamic>?> getActorProfile(String userId) async {
    final trimmed = userId.trim();
    if (trimmed.isEmpty) return null;
    try {
      final response = await _client.get(
        _uri('/api/v1/actors/$trimmed/profile'),
        headers: const {'Accept': 'application/json'},
      );
      if (response.statusCode == 404) {
        _logProfileFailure('getActorProfile', trimmed, response);
        return null;
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        _logProfileFailure('getActorProfile', trimmed, response);
        return null;
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return null;
      return _unwrapProfileBody(
        decoded.map((k, v) => MapEntry(k.toString(), v)),
      );
    } catch (_) {
      return null;
    }
  }

  void _logProfileFailure(String op, String userId, http.Response response) {
    final body = response.body;
    final tail =
        body.length > 400 ? '${body.substring(0, 400)}…' : body;
    developer.log(
      '$op userId=$userId http=${response.statusCode} body=$tail',
      name: 'UserManagementApi',
    );
  }

  /// Prefer inner `profile` object when the gateway wraps the row.
  Map<String, dynamic> _unwrapProfileBody(Map<String, dynamic> body) {
    final inner = body['profile'];
    if (inner is Map) {
      return inner.map((k, v) => MapEntry(k.toString(), v));
    }
    return body;
  }
}
