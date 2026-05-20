import 'dart:math' as math;
import 'dart:typed_data';

import 'package:http/http.dart' show ClientException;
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/actor_audition_card.dart';
import '../../models/actor_audition_submission.dart';
import '../../models/actor_callback.dart';
import '../../models/callback_status.dart';
import '../../models/actor_profile_ui.dart';
import '../../models/actor_submission_audition_ui.dart';
import '../../models/audition_listing.dart';
import '../../models/audition_submission_status.dart';
import '../../models/director_audition_card.dart';
import '../../models/director_profile_ui.dart';
import '../../utils/json_map_read.dart';
import '../../utils/jwt_user_id.dart';
import '../api/casting_api.dart';
import '../api/user_management_api.dart';

/// Result of [AuditionsRepository.submitRecordedAudition]; includes raw casting
/// `POST …/submissions` body for debug UX.
class RecordedAuditionSubmitOutcome {
  const RecordedAuditionSubmitOutcome({
    required this.submission,
    required this.createSubmissionRawBody,
  });

  final ActorAuditionSubmission submission;

  /// Exact HTTP body from casting when the submission metadata row + presigned PUT URL was created.
  final String createSubmissionRawBody;
}

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

  /// Playback URLs saved from casting POST `uploadURL` (SigV4 stripped → GET URL).
  /// Stored in SharedPreferences keyed by `submission.id` and `media_id` so GET-only
  /// flows don't lose the PUT target.
  final Map<String, String> _playbackUrlHintByMediaId = <String, String>{};
  final Map<String, String> _playbackUrlHintBySubmissionId =
      <String, String>{};

  static String _persistKeyForPlayback(String mediaId) =>
      'scenolytics_playback_url_mid_${mediaId.trim().toLowerCase()}';

  static String _persistKeyForSubmission(String castingSubmissionId) =>
      'scenolytics_playback_url_sub_${castingSubmissionId.trim().toLowerCase()}';

  Future<void> _persistPostSubmissionPlaybackUrls({
    required String strippedPlaybackUrl,
    required String castingSubmissionId,
    String? mediaId,
  }) async {
    final url = strippedPlaybackUrl.trim();
    final sid = castingSubmissionId.trim();
    if (url.isEmpty || sid.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_persistKeyForSubmission(sid), url);
    _playbackUrlHintBySubmissionId[sid] = url;

    final mid = mediaId?.trim() ?? '';
    if (mid.isNotEmpty) {
      await prefs.setString(_persistKeyForPlayback(mid), url);
      _playbackUrlHintByMediaId[mid] = url;
    }
  }

  Future<void> _hydratePlaybackHintsFromRows(
    Iterable<Map<String, dynamic>> rows,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    for (final row in rows) {
      final mediaKey =
          row['media_id']?.toString().trim() ?? row['mediaId']?.toString().trim();
      if (mediaKey != null &&
          mediaKey.isNotEmpty &&
          !_playbackUrlHintByMediaId.containsKey(mediaKey)) {
        final v = prefs.getString(_persistKeyForPlayback(mediaKey));
        if (v != null && v.trim().isNotEmpty) {
          _playbackUrlHintByMediaId[mediaKey] = v.trim();
        }
      }

      final submissionKey = row['id']?.toString().trim();
      if (submissionKey != null &&
          submissionKey.isNotEmpty &&
          !_playbackUrlHintBySubmissionId.containsKey(submissionKey)) {
        final v = prefs.getString(_persistKeyForSubmission(submissionKey));
        if (v != null && v.trim().isNotEmpty) {
          _playbackUrlHintBySubmissionId[submissionKey] = v.trim();
        }
      }
    }
  }

  Future<RecordedAuditionSubmitOutcome> submitRecordedAudition({
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

    try {
      // PUT destination is always init.uploadUrl from POST — verbatim (SigV4).
      await _castingApi.uploadSubmissionVideo(
        uploadUrl: init.uploadUrl,
        bytes: videoBytes,
      );
    } on ClientException catch (e) {
      final msgLower = e.message.toLowerCase();
      final corsHint =
          msgLower.contains('failed to fetch') ||
              msgLower.contains('xmlhttprequest error');
      throw ApiException(
        corsHint
            ? 'Video PUT failed before any HTTP status was received (${e.uri ?? init.uploadUrl}). '
                'The app used uploadURL from the casting POST unchanged. '
                'Flutter web sends OPTIONS before cross-origin PUT (required by browsers; cannot disable). '
                'If OPTIONS succeeds but uploads still fail, fix CORS (Allow-Methods/Allow-Headers) on gateway/MinIO. '
                'Or use `flutter run -d windows` to bypass browser CORS.'
            : 'Video upload failed (${e.uri ?? init.uploadUrl}): ${e.message}',
      );
    }

    final playbackFromBackend =
        _playbackUrlStripPresignedQuery(init.uploadUrl);
    final submissionMediaId = init.mediaId.trim().isNotEmpty
        ? init.mediaId.trim()
        : init.rawSubmission['media_id']?.toString().trim() ?? '';

    final mapped = _mapSubmission(
      source: init.rawSubmission,
      profile: null,
      fallbackActorName: actorName,
      fallbackAge: actorAge,
      fallbackAuditionTitle: auditionTitle,
      videoPublicBase: _videoPublicBase,
      preferredPlaybackUrl: playbackFromBackend,
    );

    final result = mapped.copyWith(id: init.submissionId);

    if (playbackFromBackend != null && playbackFromBackend.isNotEmpty) {
      await _persistPostSubmissionPlaybackUrls(
        strippedPlaybackUrl: playbackFromBackend,
        castingSubmissionId: init.submissionId,
        mediaId: submissionMediaId.isNotEmpty ? submissionMediaId : null,
      );
    }

    return RecordedAuditionSubmitOutcome(
      submission: result,
      createSubmissionRawBody: init.rawHttpBody,
    );
  }

  Future<List<ActorAuditionSubmission>> loadDirectorLeaderboard({
    required String directorToken,
    required String auditionId,
  }) async {
    final submissions = await _castingApi.getDirectorAuditionSubmissions(
      directorToken: directorToken,
      auditionId: auditionId,
    );

    await _hydratePlaybackHintsFromRows(submissions);

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
          callbackStatusCounts:
              CallbackStatusCounts.fromCallbackRows(callbacks),
          topSubmissionScore: topScore,
        );
      }),
    );

    return cards;
  }

  /// Every audition the signed-in actor has submitted to, hydrated with
  /// audition metadata, director display name, and callback row (if any).
  Future<List<ActorAuditionCard>> loadActorDashboard({
    required String actorToken,
  }) async {
    final submissions = await _safeList(
      () => _castingApi.getActorSubmissions(actorToken: actorToken),
    );
    if (submissions.isEmpty) return const <ActorAuditionCard>[];

    final callbacks = await _safeList(
      () => _castingApi.getActorCallbacks(actorToken: actorToken),
    );
    final callbackByAudition = <String, ActorCallbackInfo>{};
    for (final row in callbacks) {
      final info = ActorCallbackInfo.tryParse(row);
      if (info != null) {
        callbackByAudition[info.auditionId] = info;
      }
    }

    final latestByAudition = <String, Map<String, dynamic>>{};
    for (final row in submissions) {
      final auditionId = row['audition_id']?.toString().trim() ?? '';
      if (auditionId.isEmpty) continue;
      final existing = latestByAudition[auditionId];
      if (existing == null) {
        latestByAudition[auditionId] = row;
        continue;
      }
      final existingAt =
          DateTime.tryParse(existing['submitted_at']?.toString() ?? '');
      final candidateAt =
          DateTime.tryParse(row['submitted_at']?.toString() ?? '');
      if (candidateAt != null &&
          (existingAt == null || candidateAt.isAfter(existingAt))) {
        latestByAudition[auditionId] = row;
      }
    }

    final cards = await Future.wait(
      latestByAudition.entries.map((entry) async {
        final auditionId = entry.key;
        final subRow = entry.value;
        AuditionListing audition;
        try {
          final raw = await _castingApi.getAuditionDetails(
            token: actorToken,
            auditionId: auditionId,
          );
          audition = AuditionListing.fromJson(
            raw.isEmpty ? <String, dynamic>{'id': auditionId} : raw,
          );
          if (audition.id.isEmpty) {
            audition = AuditionListing.fromJson({...raw, 'id': auditionId});
          }
        } catch (_) {
          audition = AuditionListing.fromJson(<String, dynamic>{
            'id': auditionId,
            'title': subRow['audition_title']?.toString() ?? 'Audition',
            'type': 'Video',
            'director_id': '',
            'description': '',
            'candidate_min_age': 0,
            'candidate_max_age': 99,
            'candidate_gender': 'Both',
            'candidate_ethnicity': 'Any',
            'candidate_body_type': 'Any',
          });
        }

        String? directorName;
        final directorId = audition.directorId.trim();
        if (directorId.isNotEmpty) {
          try {
            final raw = await _userManagementApi.getDirectorProfile(
              directorId,
              bearerToken: actorToken,
            );
            if (raw != null) {
              final n = DirectorProfileUi.fromUserManagementJson(raw)
                  .displayName
                  ?.trim();
              if (n != null && n.isNotEmpty) directorName = n;
            }
          } catch (_) {}
        }
        if (directorName != null) {
          audition = audition.copyWith(directorDisplayName: directorName);
        }

        final callback = callbackByAudition[auditionId];
        final submittedAt =
            DateTime.tryParse(subRow['submitted_at']?.toString() ?? '');

        return ActorAuditionCard(
          audition: audition,
          submissionId: subRow['id']?.toString() ?? '',
          submissionStatus: parseAuditionSubmissionStatus(
            subRow['submission_status'] ?? subRow['submissionStatus'],
          ),
          submittedAt: submittedAt,
          overallScore: _firstDouble(subRow, const <String>[
            'overall_performance_score',
            'overall_score',
            'score',
          ]),
          callbackStatus: callback?.callbackStatus,
          callbackDatetime: callback?.callbackDatetime,
          meetLink: callback?.link,
        );
      }),
    );

    cards.sort((a, b) {
      final at = a.submittedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bt = b.submittedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bt.compareTo(at);
    });
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
          final raw = await _userManagementApi.getDirectorProfile(
            id,
            bearerToken: actorToken,
          );
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
          final raw = await _userManagementApi.getDirectorProfile(
            id,
            bearerToken: actorToken,
          );
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

  /// Maps `audition_submission_id` → callback row for director rankings cards.
  Future<Map<String, DirectorAuditionCallback>>
      loadDirectorCallbacksBySubmission({
    required String directorToken,
    required String auditionId,
  }) async {
    final rows = await _castingApi.getDirectorAuditionCallbacks(
      directorToken: directorToken,
      auditionId: auditionId,
    );
    final out = <String, DirectorAuditionCallback>{};
    for (final row in rows) {
      final parsed = DirectorAuditionCallback.tryParse(row);
      if (parsed == null) continue;
      out[parsed.auditionSubmissionId] = parsed;
    }
    return out;
  }

  /// Maps `audition_submission_id` → status for director rankings rows.
  Future<Map<String, CallbackStatus>> loadDirectorCallbackStatusBySubmission({
    required String directorToken,
    required String auditionId,
  }) async {
    final bySubmission = await loadDirectorCallbacksBySubmission(
      directorToken: directorToken,
      auditionId: auditionId,
    );
    return bySubmission.map((k, v) => MapEntry(k, v.status));
  }

  /// Director decision after the callback meeting (`accepted` / `rejected`).
  Future<void> reviewDirectorCallback({
    required String directorToken,
    required String auditionId,
    required String callbackId,
    required String status,
    String? directorNotes,
  }) =>
      _castingApi.reviewDirectorCallback(
        directorToken: directorToken,
        auditionId: auditionId,
        callbackId: callbackId,
        status: status,
        directorNotes: directorNotes,
      );

  Future<List<ActorCallbackInfo>> loadActorCallbacks({
    required String actorToken,
  }) async {
    final rows = await _castingApi.getActorCallbacks(actorToken: actorToken);
    final out = <ActorCallbackInfo>[];
    for (final row in rows) {
      final parsed = ActorCallbackInfo.tryParse(row);
      if (parsed != null) out.add(parsed);
    }
    return out;
  }

  Future<String> fetchDirectorGoogleCalendarAuthUrl({
    required String directorToken,
  }) =>
      _castingApi.fetchDirectorGoogleCalendarAuthUrl(
        directorToken: directorToken,
      );

  /// Picks one audition UUID from casting when the UI has none: pending invite
  /// first, then newest catalog row, then any past submission audition.
  ///
  /// Returns `null` if every actor call fails or yields no ids.
  Future<String?> resolveDefaultActorAuditionId({
    required String actorToken,
  }) async {
    if (actorToken.trim().isEmpty) return null;

    final invitations = await _safeList(
      () => _castingApi.getActorInvitations(actorToken: actorToken),
    );
    for (final row in invitations) {
      final id = row['audition_id']?.toString().trim() ?? '';
      if (id.isNotEmpty) return id;
    }

    final catalog = await _safeList(
      () => _castingApi.getActorAuditionsCatalog(actorToken: actorToken),
    );
    for (final row in catalog) {
      final id = row['id']?.toString().trim() ?? '';
      if (id.isNotEmpty) return id;
    }

    final submissions = await _safeList(
      () => _castingApi.getActorSubmissions(actorToken: actorToken),
    );
    for (final row in submissions) {
      final id = row['audition_id']?.toString().trim() ?? '';
      if (id.isNotEmpty) return id;
    }

    return null;
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

  /// Full audition row + `script` for pre-filling the director edit form.
  Future<Map<String, dynamic>> fetchAuditionDetails({
    required String token,
    required String auditionId,
  }) {
    return _castingApi.getAuditionDetails(
      token: token,
      auditionId: auditionId,
    );
  }

  /// Raw casting PATCH shape — same field names as [createDirectorAudition].
  Future<Map<String, dynamic>> updateDirectorAudition({
    required String directorToken,
    required String auditionId,
    required Map<String, dynamic> body,
  }) {
    return _castingApi.updateDirectorAudition(
      directorToken: directorToken,
      auditionId: auditionId,
      body: body,
    );
  }

  /// Director decision on a submission (`accepted` / `rejected`). Accept may require
  /// [callbackDatetime] as MariaDB `DATETIME` (`YYYY-MM-DD HH:MM:SS`, UTC) when the
  /// backend records a callback row.
  Future<void> reviewDirectorAuditionSubmission({
    required String directorToken,
    required String auditionId,
    required String submissionId,
    required String status,
    String? directorNotes,
    String? callbackDatetime,
  }) =>
      _castingApi.reviewDirectorSubmission(
        directorToken: directorToken,
        auditionId: auditionId,
        submissionId: submissionId,
        status: status,
        directorNotes: directorNotes,
        callbackDatetime: callbackDatetime,
      );

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
      final aid = auditionId.trim();
      final myRows = submissions
          .where((Map<String, dynamic> r) =>
              r['audition_id']?.toString().trim() == aid)
          .toList();
      myRows.sort((Map<String, dynamic> a, Map<String, dynamic> b) {
        final ta = DateTime.tryParse(a['submitted_at']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final tb = DateTime.tryParse(b['submitted_at']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return tb.compareTo(ta);
      });
      final latest = myRows.isEmpty ? null : myRows.first;
      final myStatus = latest == null
          ? null
          : parseAuditionSubmissionStatus(
              latest['submission_status'] ?? latest['submissionStatus'],
            );

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
          final raw = await _userManagementApi.getDirectorProfile(
            directorId,
            bearerToken: actorToken,
          );
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
        mySubmissionCountForAudition: myRows.length,
        myLatestSubmissionStatus: myStatus,
        hasSubmissionRecord: myRows.isNotEmpty,
      );
    } catch (_) {
      return const ActorSubmissionAuditionUi(
        titleLine: '',
        themeLine: '',
        emotionsCsv: '',
        directorDisplayName: null,
        myLatestSubmissionStatus: null,
        hasSubmissionRecord: false,
      );
    }
  }

  /// Casting-generated PDF (`GET …/actor/auditions/:id/script`).
  Future<Uint8List> downloadActorAuditionScriptPdf({
    required String actorToken,
    required String auditionId,
  }) =>
      _castingApi.fetchActorAuditionScriptPdf(
        actorToken: actorToken,
        auditionId: auditionId,
      );

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
    final raw = await _userManagementApi.getDirectorProfile(
      userId,
      bearerToken: directorJwt,
    );
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
    String? preferredPlaybackUrl,
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

    final mediaIdRaw =
        source['media_id']?.toString() ?? source['mediaId']?.toString();
    final preferred = preferredPlaybackUrl?.trim() ?? '';

    final mediaKey = mediaIdRaw?.trim() ?? '';
    final hintMedia =
        mediaKey.isNotEmpty ? _playbackUrlHintByMediaId[mediaKey] : null;
    final submissionKey = id.trim();
    final hintSubmission = submissionKey.isNotEmpty
        ? _playbackUrlHintBySubmissionId[submissionKey]
        : null;

    String? playback;
    if (preferred.isNotEmpty) {
      playback = preferred;
    } else if (hintMedia != null && hintMedia.trim().isNotEmpty) {
      playback = hintMedia.trim();
    } else if (hintSubmission != null && hintSubmission.trim().isNotEmpty) {
      playback = hintSubmission.trim();
    } else {
      playback = _auditionPlaybackUrl(mediaIdRaw, videoPublicBase);
    }

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
      recordedVideoUrl: playback,
      mediaId: mediaKey.isNotEmpty ? mediaKey : null,
      submissionStatus: parseAuditionSubmissionStatus(
        source['submission_status'] ?? source['submissionStatus'],
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

  /// Backend returns a SigV4 presigned **PUT** URL; [uploadSubmissionVideo]
  /// uploads to it unchanged. Playback should use the same origin + path with
  /// query/fragment removed (GET), matching where the object landed.
  String? _playbackUrlStripPresignedQuery(String presignedHttpUrl) {
    final trimmed = presignedHttpUrl.trim();
    if (trimmed.isEmpty) return null;
    Uri u;
    try {
      u = Uri.parse(trimmed);
    } on FormatException {
      return null;
    }
    if (u.scheme.isEmpty || u.host.isEmpty || u.path.isEmpty) {
      return null;
    }
    final omitPort =
        (u.scheme == 'http' && u.port == 80) ||
            (u.scheme == 'https' && u.port == 443);
    final clean = Uri(
      scheme: u.scheme,
      host: u.host,
      port: omitPort ? null : (u.hasPort ? u.port : null),
      path: u.path,
    );
    return clean.toString();
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
      mediaId: mediaId,
    );
  }
}
