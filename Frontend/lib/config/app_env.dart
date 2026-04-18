/// Compile-time config from `--dart-define` or `--dart-define-from-file=...`.
///
/// Editing [Frontend/.env] alone does **not** change these values: pass the file
/// at build/run time, e.g. `flutter run --dart-define-from-file=Frontend/.env`
/// from the repo root, or use the VS Code launch config **Scenolytics Frontend (loads Frontend/.env)**.
/// For a physical phone, use **`Frontend/.env.device`** (LAN URLs) and launch config
/// **Scenolytics Frontend phone/LAN** — edit the host in that file to your PC IPv4.
///
/// **Phones vs `localhost`:** On a **physical device**, `http://localhost` is the phone itself,
/// not your PC, so the app will **not** reach Docker on your machine. Use your computer’s
/// **LAN IP** (e.g. `http://192.168.1.42`, same port as the gateway, often 80) and allow HTTP
/// cleartext on Android if needed. **Android emulator:** use `http://10.0.2.2` to reach the host.
/// **Chrome / web on the same PC** as the backend: `http://localhost` is fine.
class AppEnv {
  /// Raw compile-time value; empty string would make Flutter **web** resolve `/api/...`
  /// against `localhost:<dev-server-port>` (404). Never expose an empty base URL.
  static const String _apiBaseUrlEnv = String.fromEnvironment(
    'SCENO_API_BASE_URL',
    defaultValue: 'http://localhost',
  );

  static String get apiBaseUrl {
    final t = _apiBaseUrlEnv.trim();
    return t.isEmpty ? 'http://localhost' : t;
  }

  /// Public base URL for audition tapes (no trailing slash). Code appends
  /// `uploads/{media_id}.mp4`.
  /// Use gateway when it proxies storage, e.g. `http://localhost/api/v1/storage/videos`.
  /// For local dev without that route, use path-style MinIO, e.g.
  /// `http://localhost:9000/videos` (same host port as backend `AWS_PORT`).
  /// On a **physical phone**, use the same **LAN host** as the API base URL (not `localhost`).
  static const String _videoPublicBaseEnv = String.fromEnvironment(
    'SCENO_VIDEO_PUBLIC_BASE',
    defaultValue: 'http://localhost/api/v1/storage/videos',
  );

  static String get videoPublicBase {
    final t = _videoPublicBaseEnv.trim();
    return t.isEmpty ? 'http://localhost/api/v1/storage/videos' : t;
  }

  static const String actorToken = String.fromEnvironment(
    'SCENO_ACTOR_TOKEN',
    defaultValue: '',
  );

  static const String directorToken = String.fromEnvironment(
    'SCENO_DIRECTOR_TOKEN',
    defaultValue: '',
  );

  static const String auditionId = String.fromEnvironment(
    'SCENO_AUDITION_ID',
    defaultValue: '',
  );

  static String? validateActorSubmissionConfig() {
    if (actorToken.isEmpty) {
      return 'Missing SCENO_ACTOR_TOKEN. Use --dart-define-from-file=Frontend/.env '
          '(see .vscode/launch.json) or --dart-define=SCENO_ACTOR_TOKEN=…';
    }
    if (auditionId.isEmpty) {
      return 'Missing SCENO_AUDITION_ID. Use the same --dart-define-from-file or '
          '--dart-define=SCENO_AUDITION_ID=…';
    }
    return null;
  }
}
