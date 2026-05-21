import 'director_google_oauth_redirect_stub.dart'
    if (dart.library.io) 'director_google_oauth_redirect_io.dart'
    if (dart.library.js_interop) 'director_google_oauth_redirect_web.dart';

Future<String> resolveDirectorGoogleOAuthRedirect({
  required Uri uri,
  required String bearerToken,
}) =>
    resolveDirectorGoogleOAuthRedirect_(uri, bearerToken);
