import 'package:flutter/material.dart';

import '../theme/scenolytics_colors.dart';

/// Icon mark + **Scenolytics** wordmark (Material icon, no image asset).
class ScenolyticsThemeAwareLogo extends StatelessWidget {
  const ScenolyticsThemeAwareLogo({
    super.key,
    this.height = 40,
    this.onHeroBackground = false,
  });

  final double height;

  /// When true, uses light icon + text (blue hero bar / drawer header).
  final bool onHeroBackground;

  double get _iconSize => (height * 0.85).clamp(28.0, 44.0);

  double get _fontSize => (height * 0.5).clamp(16.0, 22.0);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final iconColor = onHeroBackground
        ? ScenolyticsColors.onPrimary
        : (isDark ? ScenolyticsColors.onPrimary : cs.primary);
    final textColor =
        onHeroBackground ? ScenolyticsColors.onPrimary : cs.onSurface;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(
          Icons.movie_filter_rounded,
          size: _iconSize,
          color: iconColor,
        ),
        const SizedBox(width: 10),
        Text(
          'Scenolytics',
          style: TextStyle(
            fontSize: _fontSize,
            fontWeight: FontWeight.w800,
            color: textColor,
            letterSpacing: -0.5,
            height: 1.0,
          ),
        ),
      ],
    );
  }
}

Widget buildDefaultAppLogo() {
  return const ScenolyticsThemeAwareLogo();
}
