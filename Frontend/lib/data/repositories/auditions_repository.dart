import 'dart:math' as math;
import 'dart:typed_data';

import '../../models/actor_audition_submission.dart';
import '../../models/actor_profile_ui.dart';
import '../../models/actor_submission_audition_ui.dart';
import '../../models/audition_listing.dart';
import '../../models/director_audition_card.dart';
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
        .map(_actorUserIdFromSubmission)
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet();

    await Future.wait(
      actorIds.map((id) async {
        final profile = await _userManagementApi.getActorProfile(
          id,
          bearerToken: directorToken,
        );
        if (profile != null) {
          profilesByActorId[id] = profile;
        }
      }),
    );

    return submissions
        .map(
          (raw) {
            final aid = _actorUserIdFromSubmission(raw);
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

  /// Loads every audition the signed-in director owns, then fans out three
  /// per-audition queries in parallel (submissions / pending invitations /
  /// callbacks) so the dashboard can render counts + a top score without
  /// extra round-trips on the page side.
  ///
  /// Individual per-audition failures are swallowed — one bad row never
  /// breaks the dashboard.
  Future<List<DirectorAuditionCard>> loadDirectorDashboard({
    required String directorToken,
  }) async {
    final rows = await _castingApi.getDirectorAuditions(
      directorToken: directorToken,
    );
    if (rows.isEmpty) return const <DirectorAuditionCard>[];

    final auditions = rows.map(AuditionListing.fromJson).toList();

    final cards = await Future.wait(
      auditions.map((a) async {
        if (a.id.isEmpty) {
          return DirectorAuditionCard(
            audition: a,
            submissionsCount: 0,
            pendingInvitationsCount: 0,
            callbacksCount: 0,
          );
        }
        final results = await Future.wait<List<Map<String, dynamic>>>([
          _safeList(
            () => _castingApi.getDirectorAuditionSubmissions(
              directorToken: directorToken,
              auditionId: a.id,
            ),
          ),
          _safeList(
            () => _castingApi.getDirectorAuditionPendingInvitations(
              directorToken: directorToken,
              auditionId: a.id,
            ),
          ),
          _safeList(
            () => _castingApi.getDirectorAuditionCallbacks(
              directorToken: directorToken,
              auditionId: a.id,
            ),
          ),
        ]);
        final submissions = results[0];
        final pending = results[1];
        final callbacks = results[2];

        double? topScore;
        for (final row in submissions) {
          final v = _firstDouble(row, const <String>[
            'overall_performance_score',
            'overall_score',
            'score',
          ]);
          if (v == null) continue;
          if (topScore == null || v > topScore) topScore = v;
        }

        return DirectorAuditionCard(
          audition: a,
          submissionsCount: submissions.length,
          pendingInvitationsCount: pending.length,
          callbacksCount: callbacks.length,
          topSubmissionScore: topScore,
        );
      }),
    );

    return cards;
  }

  /// `DELETE /api/v1/casting/director/auditions/:id`. Throws ApiException on
  /// non-2xx so the caller can show an error message.
  Future<void> deleteDirectorAudition({
    required String directorToken,
    required String auditionId,
  }) {
    return _castingApi.deleteDirectorAudition(
      directorToken: directorToken,
      auditionId: auditionId,
    );
  }

  /// Discovers auditions the signed-in actor cares about, with no admin /
  /// catalog endpoint required. Combines three actor-allowed sources:
  ///
  /// 1. `GET /api/v1/casting/actor/invitations`            — pending invites
  /// 2. `GET /api/v1/casting/actor/auditions/submissions`  — past submissions
  /// 3. Optional [extraAuditionIds] (e.g. compile-time `SCENO_AUDITION_ID`)
  ///
  /// Each unique `audition_id` is hydrated via
  /// `GET /api/v1/casting/auditions/:id` (which any signed-in user can call),
  /// then enriched with the director display name in parallel. Failures on
  /// a single id are swallowed so one bad row never breaks the page.
  Future<List<AuditionListing>> loadAuditionsForActor({
    required String actorToken,
    List<String> extraAuditionIds = const <String>[],
  }) async {
    final invitations = await _safeList(
      () => _castingApi.getActorInvitations(actorToken: actorToken),
    );
    final submissions = await _safeList(
      () => _castingApi.getActorSubmissions(actorToken: actorToken),
    );

    final invitedIds = <String>{
      for (final row in invitations)
        if ((row['audition_id']?.toString().trim() ?? '').isNotEmpty)
          row['audition_id'].toString().trim(),
    };
    final submittedIds = <String>{
      for (final row in submissions)
        if ((row['audition_id']?.toString().trim() ?? '').isNotEmpty)
          row['audition_id'].toString().trim(),
    };

    final orderedIds = <String>[
      ...invitedIds,
      ...submittedIds.where((id) => !invitedIds.contains(id)),
      ...extraAuditionIds
          .map((id) => id.trim())
          .where((id) =>
              id.isNotEmpty &&
              !invitedIds.contains(id) &&
              !submittedIds.contains(id)),
    ];

    if (orderedIds.isEmpty) return const <AuditionListing>[];

    final fetched = await Future.wait(
      orderedIds.map((id) async {
        try {
          final raw = await _castingApi.getAuditionDetails(
            token: actorToken,
            auditionId: id,
          );
          if (raw.isEmpty) return null;
          final listing = AuditionListing.fromJson(raw);
          if (listing.id.isEmpty) {
            return AuditionListing.fromJson({...raw, 'id': id});
          }
          return listing;
        } catch (_) {
          return null;
        }
      }),
    );

    final hydrated = <AuditionListing>[
      for (final l in fetched)
        if (l != null) l,
    ];
    if (hydrated.isEmpty) return hydrated;

    final directorNames = <String, String>{};
    final uniqueDirectorIds = hydrated
        .map((a) => a.directorId)
        .where((id) => id.isNotEmpty)
        .toSet();
    await Future.wait(
      uniqueDirectorIds.map((id) async {
        try {
          final raw = await _userManagementApi.getDirectorProfile(id);
          if (raw == null) return;
          final ui = DirectorProfileUi.fromUserManagementJson(raw);
          final n = ui.displayName?.trim();
          if (n != null && n.isNotEmpty) {
            directorNames[id] = n;
          }
        } catch (_) {}
      }),
    );

    AuditionRelationship? relationshipFor(String id) {
      if (submittedIds.contains(id)) return AuditionRelationship.submitted;
      if (invitedIds.contains(id)) return AuditionRelationship.invited;
      return null;
    }

    return hydrated
        .map(
          (a) => a.copyWith(
            directorDisplayName: directorNames[a.directorId],
            relationship: relationshipFor(a.id),
          ),
        )
        .toList();
  }

  /// Loads the full catalog from `GET /api/v1/casting/actor/auditions`, enriches
  /// director display names, and the signed-in actor's invitation / submission
  /// relationship when known.
  ///
  /// Optional [extraAuditionIds] still hydrates any id missing from the catalog
  /// via `GET /api/v1/casting/auditions/:id` (e.g. deep-link / env overrides).
  Future<List<AuditionListing>> loadExploreAuditions({
    required String actorToken,
    List<String> extraAuditionIds = const <String>[],
  }) async {
    final results = await Future.wait([
      _castingApi.getActorAuditionsCatalog(actorToken: actorToken),
      _safeList(() => _castingApi.getActorInvitations(actorToken: actorToken)),
      _safeList(() => _castingApi.getActorSubmissions(actorToken: actorToken)),
    ]);

    final catalogRows = results[0];
    final invitations = results[1];
    final submissions = results[2];

    final invitedIds = <String>{
      for (final row in invitations)
        if ((row['audition_id']?.toString().trim() ?? '').isNotEmpty)
          row['audition_id'].toString().trim(),
    };
    final submittedIds = <String>{
      for (final row in submissions)
        if ((row['audition_id']?.toString().trim() ?? '').isNotEmpty)
          row['audition_id'].toString().trim(),
    };

    AuditionRelationship? relationshipFor(String id) {
      if (submittedIds.contains(id)) return AuditionRelationship.submitted;
      if (invitedIds.contains(id)) return AuditionRelationship.invited;
      return null;
    }

    final byId = <String, AuditionListing>{};
    for (final row in catalogRows) {
      final id = row['id']?.toString().trim() ?? '';
      if (id.isEmpty) continue;
      byId[id] = AuditionListing.fromJson(row);
    }

    for (final rawId in extraAuditionIds) {
      final id = rawId.trim();
      if (id.isEmpty || byId.containsKey(id)) continue;
      try {
        final raw = await _castingApi.getAuditionDetails(
          token: actorToken,
          auditionId: id,
        );
        if (raw.isEmpty) continue;
        var listing = AuditionListing.fromJson(raw);
        if (listing.id.isEmpty) {
          listing = AuditionListing.fromJson({...raw, 'id': id});
        }
        byId[listing.id] = listing;
      } catch (_) {}
    }

    final merged = byId.values.toList();
    merged.sort((a, b) {
      final ca = a.createdAt;
      final cb = b.createdAt;
      if (ca == null && cb == null) return 0;
      if (ca == null) return 1;
      if (cb == null) return -1;
      return cb.compareTo(ca);
    });

    if (merged.isEmpty) return merged;

    final directorNames = <String, String>{};
    final uniqueDirectorIds =
        merged.map((a) => a.directorId).where((id) => id.isNotEmpty).toSet();
    await Future.wait(
      uniqueDirectorIds.map((id) async {
        try {
          final raw = await _userManagementApi.getDirectorProfile(id);
          if (raw == null) return;
          final ui = DirectorProfileUi.fromUserManagementJson(raw);
          final n = ui.displayName?.trim();
          if (n != null && n.isNotEmpty) {
            directorNames[id] = n;
          }
        } catch (_) {}
      }),
    );

    return merged
        .map(
          (a) => a.copyWith(
            directorDisplayName: directorNames[a.directorId],
            relationship: relationshipFor(a.id),
          ),
        )
        .toList();
  }

  Future<List<Map<String, dynamic>>> _safeList(
    Future<List<Map<String, dynamic>>> Function() op,
  ) async {
    try {
      return await op();
    } catch (_) {
      return const <Map<String, dynamic>>[];
    }
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

  /// Raw casting POST shape — callers must send backend field names (`script` lines use `content` + `emotion`).
  Future<Map<String, dynamic>> createDirectorAudition({
    required String directorToken,
    required Map<String, dynamic> body,
  }) {
    return _castingApi.createDirectorAudition(
      directorToken: directorToken,
      body: body,
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
    final raw = await _userManagementApi.getActorProfile(
      userId,
      bearerToken: actorJwt,
    );
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

    final eyesAnalysisScore = _firstInt(source, const <String>[
          'eyes_analysis_score',
          'eye_analysis_score',
          'gaze_analysis_score',
          'eyes_score',
        ]) ??
        metrics.eyesAnalysis;

    final toneAnalysisScore = _firstInt(source, const <String>[
          'tone_analysis_score',
          'speech_tone_score',
          'prosody_score',
        ]) ??
        metrics.toneAnalysis;

    final submittedAtRaw = source['submitted_at']?.toString();
    final submittedAt =
        DateTime.tryParse(submittedAtRaw ?? '')?.toUtc() ?? DateTime.now().toUtc();

    final actorName = _submissionActorDisplayName(
      source: source,
      profile: profile,
      fallbackActorName: fallbackActorName,
    );

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
      eyesAnalysisScore: eyesAnalysisScore,
      toneAnalysisScore: toneAnalysisScore,
      recordedVideoUrl: _auditionPlaybackUrl(
        source['media_id']?.toString() ?? source['mediaId']?.toString(),
        videoPublicBase,
      ),
    );
  }

  /// Prefer User Management display name, then submission denormalized name
  /// only if it is not the raw [actor_id] / UUID-shaped (casting rows often
  /// only have [actor_id]; bad joins sometimes stuff an id into `name`).
  String _submissionActorDisplayName({
    required Map<String, dynamic> source,
    Map<String, dynamic>? profile,
    required String fallbackActorName,
  }) {
    final actorId = _actorUserIdFromSubmission(source) ?? '';

    if (profile != null && profile.isNotEmpty) {
      final fromProfile =
          ActorProfileUi.fromUserManagementJson(profile).displayName?.trim();
      if (fromProfile != null && fromProfile.isNotEmpty) {
        return fromProfile;
      }
    }

    final raw = _actorNameFromSubmissionRow(source);
    if (raw != null &&
        raw.isNotEmpty &&
        raw != actorId &&
        !_looksLikeUuid(raw)) {
      return raw;
    }

    final fb = fallbackActorName.trim();
    if (fb.isNotEmpty && fb != actorId && !_looksLikeUuid(fb)) {
      return fb;
    }

    return _shortActorIdLabel(source) ?? 'Unknown participant';
  }

  static final RegExp _uuidLike = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  bool _looksLikeUuid(String value) => _uuidLike.hasMatch(value.trim());

  String? _actorNameFromSubmissionRow(Map<String, dynamic> source) {
    final s = stringFromMap(
      source,
      const [
        'actor_name',
        'actorName',
        'ActorName',
        'display_name',
        'displayName',
        // Omit generic `name` — some pipelines echo user id there; profile wins.
      ],
    );
    if (s != null && s.isNotEmpty) {
      return s.length > 56 ? '${s.substring(0, 53)}…' : s;
    }
    return null;
  }

  /// Casting / evaluation payloads may use different keys for the actor's user id.
  String? _actorUserIdFromSubmission(Map<String, dynamic> source) {
    return stringFromMap(
      source,
      const [
        'actor_id',
        'actorId',
        'ActorId',
        'actorID',
        'user_id',
        'userId',
      ],
    );
  }

  /// Casting rows only guarantee an actor user id; used when User Management has no row.
  String? _shortActorIdLabel(Map<String, dynamic> source) {
    final id = _actorUserIdFromSubmission(source);
    if (id == null || id.isEmpty) return null;
    if (id.length <= 10) {
      return 'Actor ($id)';
    }
    return 'Actor (${id.substring(0, 8)}…)';
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
    final eyesAnalysis = nextMetric();
    final toneAnalysis = nextMetric();
    final overall =
        (emotional + vocalTone + scriptMatch + eyesAnalysis + toneAnalysis) /
            5.0;
    return _SubmissionMetrics(
      overall: overall,
      emotional: emotional,
      vocalTone: vocalTone,
      scriptMatch: scriptMatch,
      eyesAnalysis: eyesAnalysis,
      toneAnalysis: toneAnalysis,
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
    required this.eyesAnalysis,
    required this.toneAnalysis,
  });

  final double overall;
  final int emotional;
  final int vocalTone;
  final int scriptMatch;
  final int eyesAnalysis;
  final int toneAnalysis;
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
      eyesAnalysisScore: eyesAnalysisScore,
      toneAnalysisScore: toneAnalysisScore,
      recordedVideoUrl: recordedVideoUrl,
    );
  }
}
