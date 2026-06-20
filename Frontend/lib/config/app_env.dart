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
///
/// **`172.19.x.x` / `10.x.x.x`:** Often Hyper‑V/WSL virtual adapters—the phone on Wi‑Fi
/// usually cannot reach them. Prefer your **Wireless LAN adapter IPv4** from `ipconfig`, plus
/// the Docker **API_GATEWAY_PORT** if not 80.
///
/// **Notification WebSockets (Socket.IO):** The API Gateway does not proxy this service's
/// socket endpoint. Override with **`SCENO_NOTIFICATION_SOCKET_URL`** (full origin, no path),
/// e.g. `http://YOUR_LAN_HOST:6001`, or derive from [apiBaseUrl] using [notificationSocketWsPort].
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

  /// Full Socket.IO server URL (`http(s)://host:port`). When empty, we build from [apiBaseUrl]
  /// and [notificationSocketWsPort].
  static const String _notificationSocketUrlEnv = String.fromEnvironment(
    'SCENO_NOTIFICATION_SOCKET_URL',
    defaultValue: '',
  );

  /// WebSocket port mapped for `notification-service` (see backend `WEB_SOCKET_PORT`, often 6001).
  static const String _notificationSocketWsPortEnv = String.fromEnvironment(
    'SCENO_NOTIFICATION_WS_PORT',
    defaultValue: '6001',
  );

  static int get notificationSocketWsPort =>
      int.tryParse(_notificationSocketWsPortEnv.trim()) ?? 6001;

  /// Resolved Socket.IO base URL without trailing slash, or empty string if unavailable.
  static String get notificationSocketBaseUrl {
    final override = _notificationSocketUrlEnv.trim();
    if (override.isNotEmpty) return override.replaceAll(RegExp(r'/$'), '');
    try {
      final api = Uri.parse(apiBaseUrl);
      if (!api.hasScheme || api.host.isEmpty) return '';
      final port = notificationSocketWsPort;
      final defaultPort =
          api.scheme == 'https' ? 443 : (api.scheme == 'http' ? 80 : 0);
      final usePort =
          port > 0 && port != api.port && port != defaultPort ? port : null;
      final built = Uri(
        scheme: api.scheme,
        host: api.host,
        port: usePort,
      );
      return built.toString().replaceAll(RegExp(r'/$'), '');
    } catch (_) {
      return '';
    }
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

  /// Path-style MinIO bucket root for tapes (no trailing slash). Used as a playback
  /// fallback when gateway URLs 404 — default matches Docker Compose `AWS_PORT=9000`.
  /// Override with `--dart-define=SCENO_MINIO_VIDEOS_BASE=http://YOUR_HOST:9000/videos`
  /// on LAN / emulator.
  static const String _minioVideosBaseEnv = String.fromEnvironment(
    'SCENO_MINIO_VIDEOS_BASE',
    defaultValue: 'http://localhost:9000/videos',
  );

  static String get minioVideosBase {
    final t = _minioVideosBaseEnv.trim();
    return t.isEmpty ? 'http://localhost:9000/videos' : t;
  }

  /// Optional explicit MinIO/S3 origin (`scheme://host[:port]`, no path).
  /// Use on LAN devices, e.g. `http://192.168.1.42:9000`.
  static const String _minioOriginEnv = String.fromEnvironment(
    'SCENO_MINIO_ORIGIN',
    defaultValue: '',
  );

  static String get minioOrigin {
    final explicit = _minioOriginEnv.trim();
    if (explicit.isNotEmpty) {
      return explicit.replaceAll(RegExp(r'/$'), '');
    }

    try {
      final u = Uri.parse(minioVideosBase);
      if (u.hasScheme && u.host.isNotEmpty) {
        final host = u.host.toLowerCase();
        if (host != 'localhost' && host != '127.0.0.1') {
          return Uri(
            scheme: u.scheme,
            host: u.host,
            port: u.hasPort ? u.port : null,
          ).toString().replaceAll(RegExp(r'/$'), '');
        }
      }
    } catch (_) {}

    // When the API uses a LAN host, MinIO is usually on the same machine at 9000.
    try {
      final api = Uri.parse(apiBaseUrl);
      final host = api.host.toLowerCase();
      if (api.hasScheme &&
          host.isNotEmpty &&
          host != 'localhost' &&
          host != '127.0.0.1') {
        return Uri(scheme: api.scheme, host: api.host, port: 9000)
            .toString()
            .replaceAll(RegExp(r'/$'), '');
      }
    } catch (_) {}

    return 'http://localhost:9000';
  }

  /// Resolves a MinIO object reference to a URL the app/browser can GET.
  ///
  /// Accepts either an already-absolute `http(s)://…` URL (returned as-is) or a
  /// path-style `bucket/key` reference (e.g. `eye-analysis/…png`), which is
  /// prefixed with [minioOrigin]. Returns null for empty input.
  ///
  /// Rewrites `localhost` / `127.0.0.1` MinIO hosts to [minioOrigin] so eye
  /// images saved by the backend still load on phones testing against a LAN API.
  static String? minioObjectUrl(String? ref) {
    final r = ref?.trim();
    if (r == null || r.isEmpty) return null;
    final lower = r.toLowerCase();
    if (lower.startsWith('http://') || lower.startsWith('https://')) {
      try {
        final u = Uri.parse(r);
        final host = u.host.toLowerCase();
        if (host == 'localhost' || host == '127.0.0.1') {
          final origin = Uri.parse(minioOrigin);
          return Uri(
            scheme: origin.scheme,
            host: origin.host,
            port: origin.hasPort ? origin.port : null,
            path: u.path,
          ).toString();
        }
      } catch (_) {}
      return r;
    }
    final cleaned = r.startsWith('/') ? r.substring(1) : r;
    return '$minioOrigin/$cleaned';
  }

  /// Optional compile-time fallbacks. The app uses JWTs from in-app sign-in; these
  /// are only for legacy/tooling and are not required for in-app sign-in.
  static const String actorToken = String.fromEnvironment(
    'SCENO_ACTOR_TOKEN',
    defaultValue: '',
  );

  static const String directorToken = String.fromEnvironment(
    'SCENO_DIRECTOR_TOKEN',
    defaultValue: '',
  );

  /// Optional compile-time fallback when Explore did not pick an audition and casting
  /// cannot infer one yet; normally IDs come from invitations or the actor catalog APIs.
  static const String auditionId = String.fromEnvironment(
    'SCENO_AUDITION_ID',
    defaultValue: '',
  );

  /// Validates config for the actor submission flow.
  ///
  /// [auditionId] must be non-empty once resolved (typically from Explore, from
  /// casting `GET /actor/invitations` + catalog, or from optional compile-time
  /// `SCENO_AUDITION_ID`).
  static String? validateActorSubmissionFor({
    required String actorToken,
    required String auditionId,
  }) {
    if (actorToken.isEmpty) {
      return 'Sign in as an actor, or set SCENO_ACTOR_TOKEN in your run configuration '
          '(e.g. --dart-define-from-file=Frontend/.env).';
    }
    if (auditionId.trim().isEmpty) {
      return 'No audition is selected yet. Pick one under Explore Auditions, or '
          'ensure casting has invitations or catalog rows you can submit to '
          '(optional dev fallback: SCENO_AUDITION_ID).';
    }
    return null;
  }
}
