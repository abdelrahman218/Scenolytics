import 'package:flutter/material.dart';

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

  /// App bars, headers, key CTAs (light theme).
  static const LinearGradient heroBarGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [heroGradientStart, heroGradientMid, heroGradientEnd],
  );

  /// Hero banners in dark mode — one gradient for every page.
  static const LinearGradient darkHeroBarGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF0F1F35),
      heroGradientStart,
      Color(0xFF1A2D4D),
    ],
  );

  static LinearGradient heroBarGradientFor(Brightness brightness) {
    return brightness == Brightness.dark ? darkHeroBarGradient : heroBarGradient;
  }

  /// Border on hero cards over the gradient.
  static double heroBorderAlpha(Brightness brightness) {
    return brightness == Brightness.dark ? 0.12 : 0.2;
  }

  /// Glow shadow under hero cards.
  static double heroGlowShadowAlpha(Brightness brightness) {
    return brightness == Brightness.dark ? 0.35 : 0.22;
  }

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

  /// Hairline above the footer (separates from page content).
  static Color footerTopAccent(Brightness brightness) {
    return brightness == Brightness.dark
        ? accentCyan.withValues(alpha: 0.22)
        : accentCyanSoft.withValues(alpha: 0.4);
  }

  /// Muted link label on the footer bar (on dark teal / near-black).
  static const Color footerLink = Color(0xFFB8E8F2);

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
    return brightness == Brightness.dark ? darkFooterBar : surfaceMuted;
  }

  static Color outlineSoftFor(Brightness brightness) {
    return brightness == Brightness.dark ? darkOutlineSoft : outlineSoft;
  }

  static Color outlineStrongFor(Brightness brightness) {
    return brightness == Brightness.dark ? darkOutlineStrong : outlineStrong;
  }

  // —— Rankings view segmented control (sliding pill) ——
  static const Color rankingsSegmentTrackLight = Color(0xFFD2E6EE);
  static const Color rankingsSegmentTrackDark = Color(0xFF1A2F3C);
  static const Color rankingsSegmentPillLight = Color(0xFFFFFFFF);
  static const Color rankingsSegmentPillDark = Color(0xFFF2F7FA);
  static const Color rankingsSegmentSelectedLabelLight = Color(0xFF0A1F2A);
  static const Color rankingsSegmentSelectedLabelDark = Color(0xFF0D1820);
  static const Color rankingsSegmentUnselectedLabelLight = Color(0xFF5C7884);
  static const Color rankingsSegmentUnselectedLabelDark = Color(0xFF9BB4C0);

  static Color rankingsSegmentTrack(Brightness brightness) {
    return brightness == Brightness.dark
        ? rankingsSegmentTrackDark
        : rankingsSegmentTrackLight;
  }

  static Color rankingsSegmentPill(Brightness brightness) {
    return brightness == Brightness.dark
        ? rankingsSegmentPillDark
        : rankingsSegmentPillLight;
  }

  static Color rankingsSegmentSelectedLabel(Brightness brightness) {
    return brightness == Brightness.dark
        ? rankingsSegmentSelectedLabelDark
        : rankingsSegmentSelectedLabelLight;
  }

  static Color rankingsSegmentUnselectedLabel(Brightness brightness) {
    return brightness == Brightness.dark
        ? rankingsSegmentUnselectedLabelDark
        : rankingsSegmentUnselectedLabelLight;
  }

  /// Web-only gradient for the rankings toolbar “Filters” control (indigo → magenta).
  static const Color webRankingsFilterGradientStart = Color(0xFF6C5CE7);
  static const Color webRankingsFilterGradientMid = Color(0xFFB24BF3);
  static const Color webRankingsFilterGradientEnd = Color(0xFFFF2D92);
  static const LinearGradient webRankingsFilterGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [
      webRankingsFilterGradientStart,
      webRankingsFilterGradientMid,
      webRankingsFilterGradientEnd,
    ],
  );

  static const Color webRankingsFilterForeground = Color(0xFFFFFFFF);

  // —— Actor ranking cards (compact list) ——
  static const Color actorCardSurfaceLight = Color(0xFFF8FAFC);
  static const Color actorCardSurfaceDark = Color(0xFF111A24);
  static const Color actorCardBorderLight = Color(0xFFE2E8F0);
  static const Color actorCardBorderDark = Color(0xFF2A3F4D);
  static const Color actorCardMetricTrackDark = Color(0xFF1E293B);
  static const Color actorCardMetricTrackLight = Color(0xFFE2E8F0);
  static const Color metricEmotional = Color(0xFFE879F9);
  static const Color metricVocalTone = Color(0xFF38BDF8);
  static const Color metricBodyLanguage = Color(0xFF34D399);
  static const Color metricScriptMatch = Color(0xFFFBBF24);
  /// Eyes / gaze-style analysis bar on director ranking cards.
  static const Color metricEyesAnalysis = Color(0xFFA78BFA);
  /// Tone analysis bar (distinct from vocal emotion in UI copy).
  static const Color metricToneAnalysis = Color(0xFFFB7185);
  static const Color overallScoreChip = Color(0xFF22C55E);
  static const Color overallScoreChipOn = Color(0xFFFFFFFF);
  static const Color rankMedalBackdrop = Color(0xFF1E293B);
}
