import 'package:flutter/material.dart';

/// Provides the app [logo] to header, drawer, and anywhere else via [of].
///
/// Wrap [MaterialApp] (or its parent) once:
/// ```dart
/// ScenolyticsBranding(
///   logo: Image.asset('assets/logo.png', height: 40),
///   child: MaterialApp(...),
/// )
/// ```
class ScenolyticsBranding extends InheritedWidget {
  const ScenolyticsBranding({
    super.key,
    required this.logo,
    required super.child,
  });

  /// Your logo widget (image, SVG wrapper, etc.). Keep a bounded height for layout.
  final Widget logo;

  static ScenolyticsBranding? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ScenolyticsBranding>();
  }

  static ScenolyticsBranding of(BuildContext context) {
    final b = maybeOf(context);
    assert(b != null, 'ScenolyticsBranding not found above this context');
    return b!;
  }

  @override
  bool updateShouldNotify(ScenolyticsBranding oldWidget) =>
      oldWidget.logo != logo;
}
