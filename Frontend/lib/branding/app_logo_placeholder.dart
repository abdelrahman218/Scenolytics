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

/// Icon + wordmark that follow [ThemeData.colorScheme] (light / dark).
class ScenolyticsThemeAwareLogo extends StatelessWidget {
  const ScenolyticsThemeAwareLogo({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.movie_filter_rounded, color: cs.primary, size: 32),
        const SizedBox(width: 10),
        Text(
          'Scenolytics',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: cs.onSurface,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }
}
