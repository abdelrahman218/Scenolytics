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

  // —— Dark theme surfaces & text (cool cyan night) ——
  static const Color darkPageBackground = Color(0xFF061016);
  static const Color darkSurfaceCard = Color(0xFF0B1E26);
  static const Color darkSurfaceMuted = Color(0xFF122A35);
  static const Color darkSurfaceTableStripe = Color(0xFF0F242E);
  static const Color darkOutlineSoft = Color(0xFF2A5566);
  static const Color darkOutlineStrong = Color(0xFF4A7A8F);
  static const Color darkTextPrimary = Color(0xFFE8F4F8);
  static const Color darkTextSecondary = Color(0xFFB8D0DC);
  static const Color darkTextMuted = Color(0xFF7A9DAD);

  /// Dark page backdrop (deep teal → base).
  static const LinearGradient darkPageBackdropGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF0A2430), darkPageBackground],
  );

  /// Dark card surface sheen.
  static const LinearGradient darkCardSheen = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF102833), darkSurfaceCard],
  );

  /// Footer bar: same family as [primaryDim], slightly deeper for dark pages.
  static const Color darkFooterBar = Color(0xFF031018);

  static LinearGradient pageBackdropGradientFor(Brightness brightness) {
    return brightness == Brightness.dark
        ? darkPageBackdropGradient
        : pageBackdropGradient;
  }

  static LinearGradient cardSheenFor(Brightness brightness) {
    return brightness == Brightness.dark ? darkCardSheen : cardSheen;
  }

  static Color surfaceTableStripeFor(Brightness brightness) {
    return brightness == Brightness.dark
        ? darkSurfaceTableStripe
        : surfaceTableStripe;
  }

  static Color footerBarFor(Brightness brightness) {
    return brightness == Brightness.dark ? darkFooterBar : primaryDim;
  }

  static Color outlineSoftFor(Brightness brightness) {
    return brightness == Brightness.dark ? darkOutlineSoft : outlineSoft;
  }

  static Color outlineStrongFor(Brightness brightness) {
    return brightness == Brightness.dark ? darkOutlineStrong : outlineStrong;
  }
}
