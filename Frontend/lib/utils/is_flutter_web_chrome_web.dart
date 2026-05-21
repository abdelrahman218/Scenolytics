// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:html' as html;

/// True only for Google Chrome/Chromium browsers (excluding Edge).
bool get isFlutterWebChrome {
  final ua = html.window.navigator.userAgent.toLowerCase();
  if (!ua.contains('chrome')) return false;
  // Edge, Chromium-based Opera, Samsung Internet quirks
  if (ua.contains('edg/')) return false;
  if (ua.contains('opr/')) return false;
  return true;
}
