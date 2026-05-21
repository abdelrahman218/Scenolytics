import 'package:http/http.dart' as http;

Future<String> resolveDirectorGoogleOAuthRedirect_(
  Uri uri,
  String bearerToken,
) async {
  final client = http.Client();
  try {
    final req = http.Request('GET', uri)
      ..followRedirects = false
      ..headers['Authorization'] = 'Bearer ${bearerToken.trim()}';
    final streamed = await client.send(req);
    await streamed.stream.drain();

    final status = streamed.statusCode;
    final loc = streamed.headers['location']?.trim();

    if (status >= 300 && status < 400 && loc != null && loc.isNotEmpty) {
      return uri.resolve(loc).toString();
    }

    throw Exception(
      status >= 400
          ? 'Google connection failed ($status). Check your director session.'
          : 'Could not read OAuth redirect from the server.',
    );
  } finally {
    client.close();
  }
}
