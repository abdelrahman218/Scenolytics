import 'package:flutter/material.dart';

import 'branding/app_logo_placeholder.dart';
import 'branding/scenolytics_branding.dart';
import 'pages/audition_rankings_page.dart';
import 'shell/main_shell.dart';
import 'theme/app_theme.dart';

/// Your logo for the whole app. Swap this for [Image.asset], [SvgPicture], etc.
///
/// Example:
/// ```dart
/// final Widget kAppLogo = Image.asset('assets/logo.png', height: 40, fit: BoxFit.contain);
/// ```
final Widget kAppLogo = buildDefaultAppLogo();

void main() {
  runApp(ScenolyticsApp(logo: kAppLogo));
}

class ScenolyticsApp extends StatelessWidget {
  const ScenolyticsApp({super.key, required this.logo});

  /// Shown in the header, drawer, and footer via [ScenolyticsBranding].
  final Widget logo;

  @override
  Widget build(BuildContext context) {
    return ScenolyticsBranding(
      logo: logo,
      child: MaterialApp(
        title: 'Scenolytics',
        debugShowCheckedModeBanner: false,
        theme: buildScenolyticsTheme(),
        home: MainShell(
          currentRouteName: 'rankings',
          body: const AuditionRankingsPage(),
        ),
      ),
    );
  }
}
