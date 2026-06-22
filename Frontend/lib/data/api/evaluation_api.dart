import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config/app_env.dart';
import 'casting_api.dart';

/// Reads AI evaluation rows via the API gateway or a direct evaluation service URL.
class EvaluationApi {
  EvaluationApi({
    required String baseUrl,
    String? pathPrefix,
    http.Client? client,
  })  : _baseUri = Uri.parse(baseUrl),
        _pathPrefix = pathPrefix ?? AppEnv.evaluationApiPathPrefix,
        _client = client ?? http.Client();

  final Uri _baseUri;
  final String _pathPrefix;
  final http.Client _client;

  Uri _uri(String path) => _baseUri.resolve(path);

  /// Latest evaluation for [submissionId], or null if none exists (HTTP 404).
  Future<Map<String, dynamic>?> getEvaluationBySubmissionId(
    String submissionId, {
    String? bearerToken,
  }) async {
    final id = submissionId.trim();
    if (id.isEmpty) return null;
    return _getEvaluation(
      '$_pathPrefix/by-submission/$id',
      'submission $id',
      bearerToken: bearerToken,
    );
  }

  /// Fallback when the evaluation row has no submission_id (older pipeline runs).
  Future<Map<String, dynamic>?> getEvaluationByMediaId(
    String mediaId, {
    String? bearerToken,
  }) async {
    final id = mediaId.trim();
    if (id.isEmpty) return null;
    return _getEvaluation(
      '$_pathPrefix/by-media/$id',
      'media $id',
      bearerToken: bearerToken,
    );
  }

  Future<Map<String, dynamic>?> _getEvaluation(
    String path,
    String label, {
    String? bearerToken,
  }) async {
    final headers = <String, String>{
      'Accept': 'application/json',
      if (bearerToken != null && bearerToken.trim().isNotEmpty)
        'Authorization': 'Bearer ${bearerToken.trim()}',
    };

    final response = await _client.get(_uri(path), headers: headers);

    if (response.statusCode == 404) return null;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        'Failed to fetch evaluation for $label.',
        statusCode: response.statusCode,
        responseBody: response.body,
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) {
      return decoded.map((k, v) => MapEntry(k.toString(), v));
    }
    throw ApiException(
      'Unexpected evaluation response shape for $label.',
      statusCode: response.statusCode,
      responseBody: response.body,
    );
  }
}
