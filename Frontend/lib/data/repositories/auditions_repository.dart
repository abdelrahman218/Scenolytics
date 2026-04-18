import 'dart:math' as math;
import 'dart:typed_data';

import '../../models/actor_audition_submission.dart';
import '../../models/actor_profile_ui.dart';
import '../../models/actor_submission_audition_ui.dart';
import '../../models/director_profile_ui.dart';
import '../../utils/json_map_read.dart';
import '../../utils/jwt_user_id.dart';
import '../api/casting_api.dart';
import '../api/user_management_api.dart';

/// Title + subtitle line for the director rankings hero (from audition API).
class RankingsAuditionHeader {
  const RankingsAuditionHeader({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;
}

class AuditionsRepository {
  AuditionsRepository({
    required CastingApi castingApi,
    required UserManagementApi userManagementApi,
    required String videoPublicBase,
  })  : _castingApi = castingApi,
        _userManagementApi = userManagementApi,
        _videoPublicBase = videoPublicBase;

  final CastingApi _castingApi;
  final UserManagementApi _userManagementApi;
  final String _videoPublicBase;

  Future<ActorAuditionSubmission> submitRecordedAudition({
    required String actorToken,
    required String auditionId,
    required String actorName,
    required int actorAge,
    required String auditionTitle,
    required Uint8List videoBytes,
  }) async {
    final init = await _castingApi.createSubmission(
      actorToken: actorToken,
      auditionId: auditionId,
    );

    await _castingApi.uploadSubmissionVideo(
      uploadUrl: init.uploadUrl,
      bytes: videoBytes,
    );

    final mapped = _mapSubmission(
      source: init.rawSubmission,
      profile: null,
      fallbackActorName: actorName,
      fallbackAge: actorAge,
      fallbackAuditionTitle: auditionTitle,
      videoPublicBase: _videoPublicBase,
    );

    return mapped.copyWith(id: init.submissionId);
  }

  Future<List<ActorAuditionSubmission>> loadDirectorLeaderboard({
    required String directorToken,
    required String auditionId,
  }) async {
    final submissions = await _castingApi.getDirectorAuditionSubmissions(
      directorToken: directorToken,
      auditionId: auditionId,
    );

    final profilesByActorId = <String, Map<String, dynamic>>{};
    final actorIds = submissions
        .map((r) => r['actor_id']?.toString().trim())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet();

    await Future.wait(
      actorIds.map((id) async {
        final profile = await _userManagementApi.getActorProfile(id);
        if (profile != null) {
          profilesByActorId[id] = profile;
        }
      }),
    );

    return submissions
        .map(
          (raw) {
            final aid = raw['actor_id']?.toString().trim();
            final profile =
                aid != null ? profilesByActorId[aid] : null;
            return _mapSubmission(
              source: raw,
              profile: profile,
              fallbackActorName: '',
              fallbackAge: 0,
              fallbackAuditionTitle: '',
              videoPublicBase: _videoPublicBase,
            );
          },
        )
        .toList();
  }

  Future<bool> hasActorSubmittedForAudition({
    required String actorToken,
    required String auditionId,
  }) async {
    final submissions = await _castingApi.getActorSubmissions(
      actorToken: actorToken,
    );
    return submissions.any(
      (submission) => submission['audition_id']?.toString() == auditionId,
    );
  }

  /// One round-trip: audition title/theme/emotions plus director label from
  /// casting `director_id` → `GET /api/v1/directors/:id/profile`.
  Future<ActorSubmissionAuditionUi> loadActorSubmissionAuditionUi({
    required String actorToken,
    required String auditionId,
  }) async {
    try {
      final results = await Future.wait([
        _castingApi.getAuditionDetails(
          token: actorToken,
          auditionId: auditionId,
        ),
        _castingApi.getActorSubmissions(actorToken: actorToken),
      ]);
      final audition = results[0] as Map<String, dynamic>;
      final submissions = results[1] as List<Map<String, dynamic>>;
      final myCount = submissions
          .where((r) => r['audition_id']?.toString().trim() == auditionId.trim())
          .length;

      final titleLine = _auditionTitleFromMap(audition);
      // Theme line is the type pill only; emotions go in [ActorSubmissionAuditionUi.emotionsCsv]
      // so the hero is not "Video · Emotions: …" and "Requested emotion: …" with the same list.
      final themeLine = _auditionSubtitleFromMap(audition, '', includeEmotions: false);
      final emotions = _uniqueEmotionsCsvFromScript(audition['script']) ?? '';
      final description = audition['description']?.toString().trim() ?? '';
      final scriptPlainText =
          _scriptPlainTextFromAuditionScript(audition['script']);

      String? directorDisplayName;
      final directorId = _directorUserIdFromAudition(audition);
      if (directorId != null && directorId.isNotEmpty) {
        try {
          final raw = await _userManagementApi.getDirectorProfile(directorId);
          if (raw != null) {
            directorDisplayName =
                DirectorProfileUi.fromUserManagementJson(raw).displayName;
          }
        } catch (_) {}
      }

      return ActorSubmissionAuditionUi(
        titleLine: titleLine,
        themeLine: themeLine,
        emotionsCsv: emotions,
        directorDisplayName: directorDisplayName,
        description: description,
        scriptPlainText: scriptPlainText,
        mySubmissionCountForAudition: myCount,
      );
    } catch (_) {
      return const ActorSubmissionAuditionUi(
        titleLine: '',
        themeLine: '',
        emotionsCsv: '',
        directorDisplayName: null,
      );
    }
  }

  /// Casting audition row may expose director linkage under several keys or nested `director`.
  String? _directorUserIdFromAudition(Map<String, dynamic> audition) {
    const flatKeys = [
      'director_id',
      'directorId',
      'DirectorID',
      'director_user_id',
      'directorUserId',
    ];
    for (final k in flatKeys) {
      final s = audition[k]?.toString().trim();
      if (s != null && s.isNotEmpty) return s;
    }
    final nested = audition['director'];
    if (nested is Map) {
      final m = nested.map((k, v) => MapEntry(k.toString(), v));
      for (final k in [
        'user_id',
        'userId',
        'id',
        'director_id',
        'directorId',
      ]) {
        final s = m[k]?.toString().trim();
        if (s != null && s.isNotEmpty) return s;
      }
    }
    return null;
  }

  String _scriptPlainTextFromAuditionScript(Object? script) {
    if (script is! List) return '';
    final buf = StringBuffer();
    for (final row in script) {
      if (row is! Map) continue;
      final emotion = row['emotion']?.toString().trim() ?? '';
      final content = row['content']?.toString().trim() ?? '';
      if (content.isEmpty) continue;
      if (emotion.isNotEmpty) {
        buf.writeln('[$emotion]');
      }
      buf.writeln(content);
      buf.writeln();
    }
    return buf.toString().trim();
  }

  /// Actor JWT → `user_id` claim → `GET /api/v1/actors/:id/profile`.
  Future<ActorProfileUi?> loadActorProfileUi(String actorJwt) async {
    final userId = userIdFromActorJwt(actorJwt);
    if (userId == null) return null;
    final raw = await _userManagementApi.getActorProfile(userId);
    if (raw == null) return null;
    return ActorProfileUi.fromUserManagementJson(raw);
  }

  /// Director JWT → `user_id` claim → `GET /api/v1/directors/:id/profile`.
  Future<DirectorProfileUi?> loadDirectorProfileUi(String directorJwt) async {
    final userId = userIdFromActorJwt(directorJwt);
    if (userId == null) return null;
    final raw = await _userManagementApi.getDirectorProfile(userId);
    if (raw == null) return null;
    return DirectorProfileUi.fromUserManagementJson(raw);
  }

  Future<RankingsAuditionHeader> loadRankingsAuditionHeader({
    required String directorToken,
    required String auditionId,
  }) async {
    try {
      final audition = await _castingApi.getAuditionDetails(
        token: directorToken,
        auditionId: auditionId,
      );
      final title = _auditionTitleFromMap(audition);
      final subtitle = _auditionSubtitleFromMap(audition, '');
      return RankingsAuditionHeader(title: title, subtitle: subtitle);
    } catch (_) {
      return const RankingsAuditionHeader(title: '', subtitle: '');
    }
  }

  /// Title from casting audition row (supports snake_case / camelCase keys).
  String _auditionTitleFromMap(Map<String, dynamic> audition) {
    final t = stringFromMap(audition, const [
      'title',
      'Title',
      'audition_title',
      'auditionTitle',
      'name',
    ]);
    if (t != null && t.isNotEmpty) return t;
    final desc = stringFromMap(audition, const ['description', 'Description']);
    if (desc != null && desc.isNotEmpty) {
      final line = desc.split(RegExp(r'[\r\n]+')).first.trim();
      if (line.isNotEmpty) {
        return line.length > 120 ? '${line.substring(0, 117)}…' : line;
      }
    }
    return '';
  }

  String _auditionSubtitleFromMap(
    Map<String, dynamic> audition,
    String fallback, {
    bool includeEmotions = true,
  }) {
    final type = audition['type']?.toString().trim() ?? '';
    if (!includeEmotions) {
      return type.isNotEmpty ? type : fallback;
    }
    final emotions = _uniqueEmotionsCsvFromScript(audition['script']);
    final parts = <String>[];
    if (type.isNotEmpty) {
      parts.add(type);
    }
    if (emotions != null && emotions.isNotEmpty) {
      parts.add('Emotions: $emotions');
    }
    return parts.isNotEmpty ? parts.join(' · ') : fallback;
  }

  String? _uniqueEmotionsCsvFromScript(Object? script) {
    if (script is! List) return null;
    final uniqueEmotions = <String>{};
    for (final row in script) {
      if (row is! Map) continue;
      final emotion = row['emotion']?.toString().trim();
      if (emotion == null || emotion.isEmpty) continue;
      uniqueEmotions.add(_toTitleCase(emotion));
    }
    if (uniqueEmotions.isEmpty) return null;
    return uniqueEmotions.join(', ');
  }

  ActorAuditionSubmission _mapSubmission({
    required Map<String, dynamic> source,
    Map<String, dynamic>? profile,
    required String fallbackActorName,
    required int fallbackAge,
    required String fallbackAuditionTitle,
    required String videoPublicBase,
  }) {
    final id = source['id']?.toString() ?? 'sub_${DateTime.now().millisecondsSinceEpoch}';
    final metrics = _metricsFromSeed(id);

    final overallScore = _firstDouble(source, const <String>[
          'overall_performance_score',
          'overall_score',
          'score',
        ]) ??
        metrics.overall;

    final emotionalScore = _firstInt(source, const <String>[
          'facial_emotion_score',
          'facial_emotions_score',
          'emotional_expression_score',
          'emotional_score',
        ]) ??
        metrics.emotional;

    final vocalToneScore = _firstInt(source, const <String>[
          'vocal_emotion_score',
          'vocal_tone_score',
          'vocal_score',
        ]) ??
        metrics.vocalTone;

    final scriptMatchScore = _firstInt(source, const <String>[
          'script_alignment_score',
          'script_match_score',
        ]) ??
        metrics.scriptMatch;

    final submittedAtRaw = source['submitted_at']?.toString();
    final submittedAt =
        DateTime.tryParse(submittedAtRaw ?? '')?.toUtc() ?? DateTime.now().toUtc();

    final rawActorName = source['actor_name']?.toString().trim();
    final profileName = _displayNameFromActorProfile(profile);
    final actorName = (rawActorName != null && rawActorName.isNotEmpty)
        ? rawActorName
        : (profileName ?? fallbackActorName).trim();

    return ActorAuditionSubmission(
      id: id,
      actorName: actorName,
      auditionRole: source['audition_title']?.toString() ?? fallbackAuditionTitle,
      score: overallScore,
      submittedAt: submittedAt,
      age: _firstInt(source, const <String>['age']) ??
          _ageFromActorProfile(profile) ??
          fallbackAge,
      emotionalScore: emotionalScore,
      vocalToneScore: vocalToneScore,
      scriptMatchScore: scriptMatchScore,
      recordedVideoUrl: _auditionPlaybackUrl(
        source['media_id']?.toString() ?? source['mediaId']?.toString(),
        videoPublicBase,
      ),
    );
  }

  String? _displayNameFromActorProfile(Map<String, dynamic>? profile) {
    if (profile == null) return null;
    final dn = profile['display_name']?.toString().trim();
    if (dn != null && dn.isNotEmpty) {
      return dn.length > 56 ? '${dn.substring(0, 53)}…' : dn;
    }
    final bio = profile['bio']?.toString().trim();
    if (bio == null || bio.isEmpty) return null;
    final line = bio.split(RegExp(r'[\r\n]+')).first.trim();
    if (line.isEmpty) return null;
    return line.length > 56 ? '${line.substring(0, 53)}…' : line;
  }

  int? _ageFromActorProfile(Map<String, dynamic>? profile) {
    if (profile == null) return null;
    final v = profile['age'];
    if (v is int) return v;
    if (v is num) return v.round();
    if (v is String) return int.tryParse(v);
    return null;
  }

  String? _auditionPlaybackUrl(String? mediaId, String publicBase) {
    final id = mediaId?.trim();
    if (id == null || id.isEmpty) return null;
    var base = publicBase.trim();
    if (base.isEmpty) return null;
    if (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    return '$base/uploads/$id.mp4';
  }

  double? _firstDouble(Map<String, dynamic> source, List<String> keys) {
    for (final key in keys) {
      final value = source[key];
      if (value is num) return value.toDouble();
      if (value is String) {
        final parsed = double.tryParse(value);
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  int? _firstInt(Map<String, dynamic> source, List<String> keys) {
    for (final key in keys) {
      final value = source[key];
      if (value is int) return value;
      if (value is num) return value.round();
      if (value is String) {
        final parsed = int.tryParse(value);
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  _SubmissionMetrics _metricsFromSeed(String seed) {
    final seedValue = seed.codeUnits.fold<int>(0, (a, b) => a + b);
    final random = math.Random(seedValue);
    int nextMetric() => 65 + random.nextInt(31);
    final emotional = nextMetric();
    final vocalTone = nextMetric();
    final scriptMatch = nextMetric();
    final overall = (emotional + vocalTone + scriptMatch) / 3.0;
    return _SubmissionMetrics(
      overall: overall,
      emotional: emotional,
      vocalTone: vocalTone,
      scriptMatch: scriptMatch,
    );
  }

  String _toTitleCase(String raw) {
    if (raw.isEmpty) return raw;
    return raw[0].toUpperCase() + raw.substring(1).toLowerCase();
  }
}

class _SubmissionMetrics {
  const _SubmissionMetrics({
    required this.overall,
    required this.emotional,
    required this.vocalTone,
    required this.scriptMatch,
  });

  final double overall;
  final int emotional;
  final int vocalTone;
  final int scriptMatch;
}

extension on ActorAuditionSubmission {
  ActorAuditionSubmission copyWith({
    String? id,
  }) {
    return ActorAuditionSubmission(
      id: id ?? this.id,
      actorName: actorName,
      auditionRole: auditionRole,
      score: score,
      submittedAt: submittedAt,
      age: age,
      emotionalScore: emotionalScore,
      vocalToneScore: vocalToneScore,
      scriptMatchScore: scriptMatchScore,
      recordedVideoUrl: recordedVideoUrl,
    );
  }
}
