import 'package:flutter/material.dart';

import 'branding/app_logo_placeholder.dart';
import 'branding/scenolytics_branding.dart';
import 'pages/audition_rankings_page.dart';
import 'shell/main_shell.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';
import 'theme/theme_scope.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final themeController = ThemeController();
  await themeController.load();
  runApp(
    ScenolyticsApp(
      themeController: themeController,
      logo: const ScenolyticsThemeAwareLogo(),
    ),
  );
}

class ScenolyticsApp extends StatelessWidget {
  const ScenolyticsApp({
    super.key,
    required this.themeController,
    this.logo,
  });

  final ThemeController themeController;

  /// Shown in the header, drawer, and footer via [ScenolyticsBranding].
  /// Defaults to [ScenolyticsThemeAwareLogo] when omitted.
  final Widget? logo;

  @override
  Widget build(BuildContext context) {
    return ThemeControllerScope(
      controller: themeController,
      child: ScenolyticsBranding(
        logo: logo ?? const ScenolyticsThemeAwareLogo(),
        child: ListenableBuilder(
          listenable: themeController,
          builder: (context, _) {
            return MaterialApp(
              title: 'Scenolytics',
              debugShowCheckedModeBanner: false,
              theme: buildScenolyticsTheme(),
              darkTheme: buildScenolyticsDarkTheme(),
              themeMode: themeController.themeMode,
              home: MainShell(
                currentRouteName: 'rankings',
                body: const AuditionRankingsPage(),
              ),
            );
          },
        ),
      ),
    );
  }
}
