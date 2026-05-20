import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Uses Fetch `redirect: manual` so the browser does **not** follow the 302 to
/// Google (XHR/`package:http` on web follows redirects and trips Google's CORS).
Future<String> resolveDirectorGoogleOAuthRedirect_(
  Uri uri,
  String bearerToken,
) async {
  final headers = web.Headers()
    ..set('Authorization', 'Bearer ${bearerToken.trim()}');

  final init = web.RequestInit(
    method: 'GET',
    headers: headers,
    redirect: 'manual',
  );

  late web.Response response;
  try {
    response =
        await web.window.fetch(uri.toString().toJS, init).toDart;
  } catch (e, st) {
    Error.throwWithStackTrace(Exception('fetch failed: $e'), st);
  }

  final status = response.status;
  final rtype = response.type;

  // Cross-origin redirect targets become opaque — Location is not readable.
  if (rtype == 'opaqueredirect') {
    throw Exception(
      'This browser cannot expose the Google sign-in URL for a cross-origin '
      'API (${uri.origin}). Use Flutter desktop (`flutter run -d windows`), '
      'or serve the web app from the same host/port as your API gateway.',
    );
  }

  final loc =
      response.headers.get('Location') ?? response.headers.get('location');

  if (status >= 300 && status < 400 && loc != null && loc.trim().isNotEmpty) {
    return uri.resolve(loc.trim()).toString();
  }

  throw Exception(
    'Google connect returned HTTP $status (response type: $rtype). '
    '${loc == null ? 'No Location header.' : ''}',
  );
}
