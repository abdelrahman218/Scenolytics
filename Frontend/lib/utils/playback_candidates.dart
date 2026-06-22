import '../config/app_env.dart';
import '../models/actor_audition_submission.dart';

/// Ordered list of URLs to try when playing a submission's recording.
///
/// Mirrors the director rankings media sheet resolution: the repository's
/// resolved URL first, then MinIO / gateway / direct-host fallbacks derived
/// from the media id. The player probes each in order until one initializes.
List<String> submissionPlaybackCandidates(ActorAuditionSubmission submission) {
  final out = <String>[];
  final seen = <String>{};
  void add(String? raw) {
    final u = raw?.trim();
    if (u == null || u.isEmpty) return;
    if (!seen.add(u)) return;
    out.add(u);
  }

  add(submission.recordedVideoUrl);

  final id = submission.mediaId?.trim();
  if (id != null && id.isNotEmpty) {
    String tapeAtPublicBase(String rawBase) {
      var base = rawBase.trim();
      if (base.isEmpty) return '';
      if (base.endsWith('/')) base = base.substring(0, base.length - 1);
      return '$base/uploads/$id.mp4';
    }

    add(tapeAtPublicBase(AppEnv.minioVideosBase));
    add(tapeAtPublicBase(AppEnv.videoPublicBase));

    Uri? api;
    try {
      api = Uri.parse(AppEnv.apiBaseUrl);
    } catch (_) {
      api = null;
    }
    if (api != null &&
        (api.scheme == 'http' || api.scheme == 'https') &&
        api.host.isNotEmpty &&
        api.host.toLowerCase() != 'localhost' &&
        api.host != '127.0.0.1') {
      add('${api.scheme}://${api.host}:9000/videos/uploads/$id.mp4');
    }
  }

  return out;
}
