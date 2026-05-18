import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.responseBody});

  final String message;
  final int? statusCode;
  final String? responseBody;

  @override
  String toString() => 'ApiException(statusCode: $statusCode, message: $message)';
}

class CastingSubmissionInitResponse {
  const CastingSubmissionInitResponse({
    required this.submissionId,
    required this.mediaId,
    required this.uploadUrl,
    required this.rawSubmission,
  });

  final String submissionId;
  final String mediaId;
  final String uploadUrl;
  final Map<String, dynamic> rawSubmission;
}

class CastingApi {
  CastingApi({
    required String baseUrl,
    http.Client? client,
  })  : _baseUri = Uri.parse(baseUrl),
        _client = client ?? http.Client();

  final Uri _baseUri;
  final http.Client _client;

  Uri _uri(String path) => _baseUri.resolve(path);

  Map<String, String> _authHeaders(String token) => <String, String>{
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };

  Future<CastingSubmissionInitResponse> createSubmission({
    required String actorToken,
    required String auditionId,
  }) async {
    final response = await _client.post(
      _uri('/api/v1/casting/actor/auditions/$auditionId/submissions'),
      headers: _authHeaders(actorToken),
      body: '{}',
    );

    final body = _decodeJsonMap(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        body['message']?.toString() ?? 'Failed to create submission metadata.',
        statusCode: response.statusCode,
        responseBody: response.body,
      );
    }

    final submission = _asMap(body['submission']);
    final submissionId = submission['id']?.toString() ?? '';
    final mediaId = submission['media_id']?.toString() ?? '';
    final uploadUrl =
        body['uploadURL']?.toString() ?? body['upload_url']?.toString() ?? '';

    if (submissionId.isEmpty || mediaId.isEmpty || uploadUrl.isEmpty) {
      throw ApiException(
        'Submission response is missing required fields (id/media_id/uploadURL).',
        statusCode: response.statusCode,
        responseBody: response.body,
      );
    }

    return CastingSubmissionInitResponse(
      submissionId: submissionId,
      mediaId: mediaId,
      uploadUrl: uploadUrl,
      rawSubmission: submission,
    );
  }

  Future<void> uploadSubmissionVideo({
    required String uploadUrl,
    required Uint8List bytes,
  }) async {
    // Presigned PUT from PutObjectCommand(Bucket, Key) is signed without
    // Content-Type. Sending Content-Type here often breaks SigV4 (403).
    final response = await _client.put(
      Uri.parse(uploadUrl),
      body: bytes,
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final detail = response.body.isNotEmpty
          ? response.body.replaceAll(RegExp(r'\s+'), ' ').trim()
          : '';
      final suffix =
          detail.isEmpty ? '' : ' (${detail.length > 160 ? '${detail.substring(0, 160)}…' : detail})';
      throw ApiException(
        'Video upload failed (HTTP ${response.statusCode}). '
        'Submission was already created; fix upload or remove the row in casting DB before retry.$suffix',
        statusCode: response.statusCode,
        responseBody: response.body,
      );
    }
  }

  Future<List<Map<String, dynamic>>> getActorSubmissions({
    required String actorToken,
  }) async {
    final response = await _client.get(
      _uri('/api/v1/casting/actor/auditions/submissions'),
      headers: _authHeaders(actorToken),
    );
    return _decodeJsonList(response, 'Failed to fetch actor submissions.');
  }

  Future<List<Map<String, dynamic>>> getDirectorAuditionSubmissions({
    required String directorToken,
    required String auditionId,
  }) async {
    final response = await _client.get(
      _uri('/api/v1/casting/director/auditions/$auditionId/submissions'),
      headers: _authHeaders(directorToken),
    );
    return _decodeJsonList(response, 'Failed to fetch director submissions.');
  }

  Future<Map<String, dynamic>> getAuditionDetails({
    required String token,
    required String auditionId,
  }) async {
    final response = await _client.get(
      _uri('/api/v1/casting/auditions/$auditionId'),
      headers: _authHeaders(token),
    );
    final body = _decodeJsonMap(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        body['message']?.toString() ?? 'Failed to fetch audition details.',
        statusCode: response.statusCode,
        responseBody: response.body,
      );
    }

    return _asMap(body['audition']);
  }

  /// POST `/director/auditions/create_audition` — body must match casting service expectations.
  Future<Map<String, dynamic>> createDirectorAudition({
    required String directorToken,
    required Map<String, dynamic> body,
  }) async {
    final response = await _client.post(
      _uri('/api/v1/casting/director/auditions/create_audition'),
      headers: _authHeaders(directorToken),
      body: jsonEncode(body),
    );
    final decoded = _decodeJsonMap(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        decoded['message']?.toString() ?? 'Failed to create audition.',
        statusCode: response.statusCode,
        responseBody: response.body,
      );
    }
    return _asMap(decoded['audition']);
  }

  List<Map<String, dynamic>> _decodeJsonList(
    http.Response response,
    String fallbackMessage,
  ) {
    final decoded = response.body.isEmpty ? null : jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded is Map<String, dynamic>
          ? decoded['message']?.toString() ?? fallbackMessage
          : fallbackMessage;
      throw ApiException(
        message,
        statusCode: response.statusCode,
        responseBody: response.body,
      );
    }

    if (decoded is! List) {
      throw ApiException(
        'Expected a JSON list response.',
        statusCode: response.statusCode,
        responseBody: response.body,
      );
    }
    return decoded
        .whereType<Map>()
        .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
        .toList();
  }

  Map<String, dynamic> _decodeJsonMap(http.Response response) {
    final decoded = response.body.isEmpty ? <String, dynamic>{} : jsonDecode(response.body);
    if (decoded is! Map) {
      return <String, dynamic>{};
    }
    return decoded.map((k, v) => MapEntry(k.toString(), v));
  }

  Map<String, dynamic> _asMap(Object? value) {
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), v));
    }
    return <String, dynamic>{};
  }
}
