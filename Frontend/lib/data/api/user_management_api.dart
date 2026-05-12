import 'dart:convert';
import 'dart:developer' as developer;

import 'package:http/http.dart' as http;

/// Thrown when a write to the User Management service fails (non-2xx).
class UserManagementApiException implements Exception {
  UserManagementApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// Reads/writes actor & director profile rows via the API gateway (`/api/v1/...`).
class UserManagementApi {
  UserManagementApi({
    required String baseUrl,
    http.Client? client,
  })  : _baseUri = Uri.parse(baseUrl),
        _client = client ?? http.Client();

  final Uri _baseUri;
  final http.Client _client;

  Uri _uri(String path) => _baseUri.resolve(path);

  static const _jsonHeaders = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

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
  ///
  /// When [bearerToken] is set (e.g. director JWT on rankings, or the actor's own
  /// token on profile), it is sent as `Authorization: Bearer …` so gateways that
  /// require auth for `GET /actors/.../profile` still return a row.
  Future<Map<String, dynamic>?> getActorProfile(
    String userId, {
    String? bearerToken,
  }) async {
    final trimmed = userId.trim();
    if (trimmed.isEmpty) return null;
    final headers = <String, String>{
      'Accept': 'application/json',
      if (bearerToken != null && bearerToken.trim().isNotEmpty)
        'Authorization': 'Bearer ${bearerToken.trim()}',
    };
    try {
      final response = await _client.get(
        _uri('/api/v1/actors/$trimmed/profile'),
        headers: headers,
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

  /// Prefer inner `profile` or `data` when the gateway wraps the row.
  Map<String, dynamic> _unwrapProfileBody(Map<String, dynamic> body) {
    for (final key in const [
      'profile',
      'data',
      'actor',
      'actor_profile',
      'actorProfile',
      'result',
    ]) {
      final inner = body[key];
      if (inner is Map) {
        return inner.map((k, v) => MapEntry(k.toString(), v));
      }
    }
    return body;
  }

  /// `POST /api/v1/actors/profile` — creates a new actor profile row.
  /// Returns the created row (or the request body merged with server fields) on success.
  Future<Map<String, dynamic>> createActorProfile({
    required String userId,
    required Map<String, dynamic> fields,
  }) async {
    return _writeProfile(
      method: 'POST',
      path: '/api/v1/actors/profile',
      body: <String, dynamic>{'user_id': userId.trim(), ...fields},
      op: 'createActorProfile',
    );
  }

  /// `PATCH /api/v1/actors/profile/:profile_id` — updates an actor profile row.
  Future<Map<String, dynamic>> updateActorProfile({
    required String profileId,
    required Map<String, dynamic> fields,
  }) async {
    return _writeProfile(
      method: 'PATCH',
      path: '/api/v1/actors/profile/${profileId.trim()}',
      body: fields,
      op: 'updateActorProfile',
    );
  }

  /// `POST /api/v1/directors/profile` — creates a new director profile row.
  Future<Map<String, dynamic>> createDirectorProfile({
    required String userId,
    required Map<String, dynamic> fields,
  }) async {
    return _writeProfile(
      method: 'POST',
      path: '/api/v1/directors/profile',
      body: <String, dynamic>{'user_id': userId.trim(), ...fields},
      op: 'createDirectorProfile',
    );
  }

  /// `PATCH /api/v1/directors/profile/:profile_id` — updates a director profile row.
  Future<Map<String, dynamic>> updateDirectorProfile({
    required String profileId,
    required Map<String, dynamic> fields,
  }) async {
    return _writeProfile(
      method: 'PATCH',
      path: '/api/v1/directors/profile/${profileId.trim()}',
      body: fields,
      op: 'updateDirectorProfile',
    );
  }

  Future<Map<String, dynamic>> _writeProfile({
    required String method,
    required String path,
    required Map<String, dynamic> body,
    required String op,
  }) async {
    http.Response response;
    final encoded = jsonEncode(body);
    final uri = _uri(path);
    if (method == 'POST') {
      response = await _client.post(uri, headers: _jsonHeaders, body: encoded);
    } else {
      response = await _client.patch(uri, headers: _jsonHeaders, body: encoded);
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map) {
          return _unwrapProfileBody(
            decoded.map((k, v) => MapEntry(k.toString(), v)),
          );
        }
      } catch (_) {}
      return body;
    }
    _logProfileFailure(op, body['user_id']?.toString() ?? '', response);
    throw UserManagementApiException(
      _extractMessage(response.body) ?? 'Could not save profile.',
      statusCode: response.statusCode,
    );
  }

  String? _extractMessage(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        final m = decoded['message']?.toString();
        if (m != null && m.trim().isNotEmpty) return m.trim();
        final errs = decoded['errors'];
        if (errs is List && errs.isNotEmpty) {
          return errs.map((e) => e.toString()).join('; ');
        }
      }
    } catch (_) {}
    return null;
  }
}
