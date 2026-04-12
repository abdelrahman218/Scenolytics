import 'package:flutter/material.dart';

/// Scenolytics design tokens — cyan / blue family.
///
/// Use these names anywhere so the app stays consistent:
/// ```dart
/// import 'package:scenolytics_frontend/theme/scenolytics_colors.dart';
///
/// color: ScenolyticsColors.primary,
/// decoration: BoxDecoration(gradient: ScenolyticsColors.heroBarGradient),
/// ```
abstract final class ScenolyticsColors {
  // —— Brand (primary ramp) ——
  static const Color primary = Color(0xFF006884);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color primaryBright = Color(0xFF00A3C4);
  static const Color primaryDim = Color(0xFF004D63);
  static const Color primaryContainer = Color(0xFFB8ECF5);
  static const Color onPrimaryContainer = Color(0xFF003544);

  // —— Accent (cyan pop) ——
  static const Color accentCyan = Color(0xFF00B4D8);
  static const Color accentCyanSoft = Color(0xFF48CAE4);
  static const Color accentCyanMuted = Color(0xFFC5F1FF);
  static const Color onAccentCyan = Color(0xFF00232C);

  // —— Secondary / supporting blue ——
  static const Color secondary = Color(0xFF118AB2);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color secondaryContainer = Color(0xFFD0EEF7);
  static const Color onSecondaryContainer = Color(0xFF003547);

  // —— Tertiary (indigo-violet for charts / chips) ——
  static const Color tertiary = Color(0xFF5C6BC0);
  static const Color onTertiary = Color(0xFFFFFFFF);
  static const Color tertiaryContainer = Color(0xFFE0E4FF);
  static const Color onTertiaryContainer = Color(0xFF1A237E);

  // —— Surfaces & structure ——
  static const Color pageBackground = Color(0xFFF2FAFC);
  static const Color surfaceCard = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFE5F4F8);
  static const Color surfaceTableStripe = Color(0xFFE8F5F9);
  static const Color outlineSoft = Color(0xFFB8D4DE);
  static const Color outlineStrong = Color(0xFF6FA3B5);

  // —— Text ——
  static const Color textPrimary = Color(0xFF0A1F2A);
  static const Color textSecondary = Color(0xFF3D5A66);
  static const Color textMuted = Color(0xFF6B8794);

  // —— Semantic (still harmonized with cool palette) ——
  static const Color success = Color(0xFF0D9488);
  static const Color onSuccess = Color(0xFFFFFFFF);
  static const Color successContainer = Color(0xFFCCFBF1);

  static const Color warning = Color(0xFFD97706);
  static const Color warningContainer = Color(0xFFFEF3C7);

  static const Color error = Color(0xFFDC2626);
  static const Color errorContainer = Color(0xFFFEE2E2);

  static const Color info = Color(0xFF0284C7);
  static const Color infoContainer = Color(0xFFE0F2FE);

  // —— Leaderboard medals ——
  static const Color rankGold = Color(0xFFFFD54F);
  static const Color rankGoldText = Color(0xFF5D4037);
  static const Color rankSilver = Color(0xFFE2E8F0);
  static const Color rankSilverText = Color(0xFF334155);
  static const Color rankBronze = Color(0xFFCD7F32);
  static const Color rankBronzeText = Color(0xFFFFFFFF);

  // —— Hero / marketing gradients ——
  static const Color heroGradientStart = Color(0xFF023E8A);
  static const Color heroGradientMid = Color(0xFF0077B6);
  static const Color heroGradientEnd = Color(0xFF00B4D8);

  /// App bars, headers, key CTAs.
  static const LinearGradient heroBarGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [heroGradientStart, heroGradientMid, heroGradientEnd],
  );

  /// Subtle page backdrop (very light).
  static const LinearGradient pageBackdropGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFE8F7FB), pageBackground],
  );

  /// Cards / chips — light cyan wash.
  static const LinearGradient cardSheen = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFFFFF), Color(0xFFF0FAFD)],
  );
}
