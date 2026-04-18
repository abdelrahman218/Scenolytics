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

/// Dark Material 3 theme — same brand hues, tuned for night surfaces.
ThemeData buildScenolyticsDarkTheme() {
  const scheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFF5DD5F0),
    onPrimary: Color(0xFF003544),
    primaryContainer: Color(0xFF004D63),
    onPrimaryContainer: Color(0xFFB8ECF5),
    secondary: Color(0xFF7FC9E8),
    onSecondary: Color(0xFF003547),
    secondaryContainer: Color(0xFF1A4A5C),
    onSecondaryContainer: Color(0xFFD0EEF7),
    tertiary: Color(0xFFB4C0FF),
    onTertiary: Color(0xFF1A237E),
    tertiaryContainer: Color(0xFF303F9F),
    onTertiaryContainer: Color(0xFFE0E4FF),
    error: Color(0xFFFFB4AB),
    onError: Color(0xFF690005),
    errorContainer: Color(0xFF93000A),
    onErrorContainer: Color(0xFFFFDAD6),
    surface: ScenolyticsColors.darkSurfaceCard,
    onSurface: ScenolyticsColors.darkTextPrimary,
    surfaceContainerHighest: ScenolyticsColors.darkSurfaceMuted,
    onSurfaceVariant: ScenolyticsColors.darkTextSecondary,
    outline: ScenolyticsColors.darkOutlineSoft,
    outlineVariant: Color(0xFF1E3D4A),
    shadow: Color(0x66000000),
    scrim: Color(0xCC000000),
    inverseSurface: Color(0xFFE8F4F8),
    onInverseSurface: Color(0xFF0A1F2A),
    inversePrimary: ScenolyticsColors.primary,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: ScenolyticsColors.darkPageBackground,
    appBarTheme: const AppBarTheme(
      elevation: 0,
      centerTitle: false,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: ScenolyticsColors.darkSurfaceCard,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: ScenolyticsColors.darkOutlineSoft.withValues(alpha: 0.55),
        ),
      ),
      clipBehavior: Clip.antiAlias,
    ),
    dividerTheme: DividerThemeData(
      color: ScenolyticsColors.darkOutlineSoft.withValues(alpha: 0.5),
      thickness: 1,
    ),
    iconTheme: const IconThemeData(color: Color(0xFF5DD5F0)),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: Color(0xFF00B4D8),
      foregroundColor: Color(0xFF00232C),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Color(0xFF0F3D4D),
      labelStyle: const TextStyle(
        color: Color(0xFFC5F1FF),
        fontWeight: FontWeight.w600,
      ),
      side: BorderSide(
        color: const Color(0xFF00B4D8).withValues(alpha: 0.35),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: Color(0xFF5DD5F0),
    ),
  );
}
