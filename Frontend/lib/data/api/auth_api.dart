import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/auth_user.dart';

class AuthApiException implements Exception {
  AuthApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// Identity Provider routes via API gateway: `/api/v1/auth/...`
class AuthApi {
  AuthApi({required String baseUrl, http.Client? client})
      : _baseUri = Uri.parse(baseUrl),
        _client = client ?? http.Client();

  final Uri _baseUri;
  final http.Client _client;

  Uri _uri(String path) => _baseUri.resolve(path);

  bool _looksLikeNetworkFailure(Object error) {
    if (error is http.ClientException) return true;
    final t = error.toString().toLowerCase();
    return t.contains('socketexception') ||
        t.contains('failed host lookup') ||
        t.contains('connection refused') ||
        t.contains('connection reset') ||
        t.contains('connection timed out') ||
        t.contains('network is unreachable') ||
        t.contains('no route to host') ||
        t.contains('software caused connection abort');
  }

  /// Plain-language hint when [SocketException] / [ClientException] prevents reaching auth.
  String _networkTroubleshoot(Object error) {
    final uri = _baseUri;
    final origin = uri.hasScheme && uri.host.isNotEmpty
        ? uri.origin
        : uri.toString();

    final buf = StringBuffer(
      'Cannot reach the identity API at $origin (${error.runtimeType}). ',
    );

    final host = uri.host.toLowerCase();
    if (host == 'localhost' ||
        host == '127.0.0.1' ||
        host == '::1' ||
        host == '[::1]') {
      buf.write(
        'On a physical phone, localhost is the phone itself, not your PC. ',
      );
      buf.write(
        'Use your computer Wi‑Fi IPv4 (run ipconfig → Wireless LAN) plus Docker '
        'gateway port in SCENO_API_BASE_URL, e.g. '
        'http://192.168.1.50:8080 — passed via '
        '--dart-define-from-file=Frontend/.env.device at flutter run/build. ',
      );
    }

    if (host.startsWith('172.') || host.startsWith('10.')) {
      buf.write(
        'Address $host may be a Hyper‑V/WSL/virtual adapter many phones cannot '
        'route to; try your Wi‑Fi adapter IPv4 instead. ',
      );
    }

    buf.write(
      'Ensure Docker publishes API_GATEWAY_PORT. On Windows, if Wi‑Fi is a Public network, '
      'inbound LAN traffic is blocked unless you set the network to Private or run '
      'Backend/scripts/allow-lan-firewall.ps1 as Administrator. For USB debugging, use '
      'Frontend/.env.usb after Frontend/scripts/setup-android-usb.ps1.',
    );

    return buf.toString().trim();
  }

  Future<http.Response> _postAuthJson(Uri uri, String body) async {
    try {
      return await _client.post(uri, headers: _jsonHeaders, body: body);
    } catch (e) {
      if (_looksLikeNetworkFailure(e)) {
        throw AuthApiException(_networkTroubleshoot(e));
      }
      rethrow;
    }
  }

  static const _jsonHeaders = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  /// `POST /api/v1/auth/login` — returns JWT and user.
  Future<AuthUser> logIn({required String email, required String password}) async {
    final response = await _postAuthJson(
      _uri('/api/v1/auth/login'),
      jsonEncode({
        'email': email.trim(),
        'password': password,
      }),
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = _decodeObject(response.body);
      final token = data['token']?.toString().trim() ?? '';
      final u = _parseUserMap(data['user']) ?? <String, dynamic>{};
      final id = (u['user_id'] ?? u['userId'])?.toString().trim() ?? '';
      final em = (u['email'] ?? email).toString().trim();
      final role = (u['role'] ?? '').toString().trim().toLowerCase();
      if (token.isEmpty || id.isEmpty || role.isEmpty) {
        throw AuthApiException('Unexpected login response from server.');
      }
      return AuthUser(token: token, userId: id, email: em, role: role);
    }
    throw _errorFromResponse(response, fallback: 'Sign in failed.');
  }

  /// `POST /api/v1/auth/signup` — creates user (no token). Caller usually logs in next.
  ///
  /// The Identity Provider only persists `email`, `password`, and `role`. We still
  /// send [name], plus [age] / [gender] for actors, so any future gateway/profile
  /// hook can pick them up. Today the backend ignores unknown keys.
  Future<void> signUp({
    required String email,
    required String password,
    required String role,
    required String name,
    int? age,
    String? gender,
  }) async {
    final body = <String, dynamic>{
      'email': email.trim(),
      'password': password,
      'role': role.trim().toLowerCase(),
      'name': name.trim(),
    };
    if (age != null) body['age'] = age;
    final g = gender?.trim();
    if (g != null && g.isNotEmpty) body['gender'] = g;
    final response = await _postAuthJson(
      _uri('/api/v1/auth/signup'),
      jsonEncode(body),
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }
    if (response.statusCode == 409) {
      throw _errorFromResponse(
        response,
        fallback: 'An account with this email already exists.',
      );
    }
    throw _errorFromResponse(response, fallback: 'Could not create account.');
  }

  Map<String, dynamic> _decodeObject(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map) {
      return <String, dynamic>{};
    }
    return decoded.map((k, v) => MapEntry(k.toString(), v));
  }

  Map<String, dynamic>? _parseUserMap(dynamic value) {
    if (value is! Map) return null;
    return value.map((k, v) => MapEntry(k.toString(), v));
  }

  AuthApiException _errorFromResponse(
    http.Response response, {
    required String fallback,
  }) {
    String message = fallback;
    try {
      final data = _decodeObject(response.body);
      final m = data['message']?.toString();
      if (m != null && m.trim().isNotEmpty) {
        message = m.trim();
      }
    } catch (_) {}
    return AuthApiException(message, statusCode: response.statusCode);
  }
}
