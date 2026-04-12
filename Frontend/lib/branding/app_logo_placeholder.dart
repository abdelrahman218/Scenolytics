import 'package:flutter/material.dart';

import '../theme/scenolytics_colors.dart';

/// Default logo until you pass your own to [ScenolyticsApp] / [ScenolyticsBranding].
///
/// Replace globally by setting your asset in [main.dart]:
/// ```dart
/// runApp(ScenolyticsApp(
///   logo: Image.asset('assets/logo.png', height: 40, fit: BoxFit.contain),
/// ));
/// ```
Widget buildDefaultAppLogo() {
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(
        Icons.movie_filter_rounded,
        color: ScenolyticsColors.primary,
        size: 32,
      ),
      const SizedBox(width: 10),
      Text(
        'Scenolytics',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: ScenolyticsColors.textPrimary,
          letterSpacing: -0.5,
        ),
      ),
    ],
  );
}
