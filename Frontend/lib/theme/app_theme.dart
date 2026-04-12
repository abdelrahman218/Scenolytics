import 'package:flutter/material.dart';

import 'scenolytics_colors.dart';

/// Material 3 theme wired to [ScenolyticsColors].
ThemeData buildScenolyticsTheme() {
  const scheme = ColorScheme(
    brightness: Brightness.light,
    primary: ScenolyticsColors.primary,
    onPrimary: ScenolyticsColors.onPrimary,
    primaryContainer: ScenolyticsColors.primaryContainer,
    onPrimaryContainer: ScenolyticsColors.onPrimaryContainer,
    secondary: ScenolyticsColors.secondary,
    onSecondary: ScenolyticsColors.onSecondary,
    secondaryContainer: ScenolyticsColors.secondaryContainer,
    onSecondaryContainer: ScenolyticsColors.onSecondaryContainer,
    tertiary: ScenolyticsColors.tertiary,
    onTertiary: ScenolyticsColors.onTertiary,
    tertiaryContainer: ScenolyticsColors.tertiaryContainer,
    onTertiaryContainer: ScenolyticsColors.onTertiaryContainer,
    error: ScenolyticsColors.error,
    onError: ScenolyticsColors.onPrimary,
    errorContainer: ScenolyticsColors.errorContainer,
    onErrorContainer: Color(0xFF7F1D1D),
    surface: ScenolyticsColors.surfaceCard,
    onSurface: ScenolyticsColors.textPrimary,
    surfaceContainerHighest: ScenolyticsColors.surfaceMuted,
    onSurfaceVariant: ScenolyticsColors.textSecondary,
    outline: ScenolyticsColors.outlineSoft,
    outlineVariant: Color(0xFFD0E8EF),
    shadow: Color(0x400A1F2A),
    scrim: Color(0xCC0A1F2A),
    inverseSurface: ScenolyticsColors.primaryDim,
    onInverseSurface: ScenolyticsColors.onPrimary,
    inversePrimary: ScenolyticsColors.accentCyanSoft,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: ScenolyticsColors.pageBackground,
    appBarTheme: const AppBarTheme(
      elevation: 0,
      centerTitle: false,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: ScenolyticsColors.surfaceCard,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: ScenolyticsColors.outlineSoft.withValues(alpha: 0.45),
        ),
      ),
      clipBehavior: Clip.antiAlias,
    ),
    dividerTheme: DividerThemeData(
      color: ScenolyticsColors.outlineSoft.withValues(alpha: 0.6),
      thickness: 1,
    ),
    iconTheme: const IconThemeData(color: ScenolyticsColors.primary),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: ScenolyticsColors.accentCyan,
      foregroundColor: ScenolyticsColors.onAccentCyan,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: ScenolyticsColors.accentCyanMuted,
      labelStyle: const TextStyle(
        color: ScenolyticsColors.onAccentCyan,
        fontWeight: FontWeight.w600,
      ),
      side: BorderSide(
        color: ScenolyticsColors.accentCyan.withValues(alpha: 0.35),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: ScenolyticsColors.primary,
    ),
  );
}
