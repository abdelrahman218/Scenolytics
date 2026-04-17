import 'package:flutter/material.dart';

import 'data/mock_audition_rankings.dart';
import 'branding/app_logo_placeholder.dart';
import 'branding/scenolytics_branding.dart';
import 'models/actor_audition_submission.dart';
import 'pages/audition_rankings_page.dart';
import 'pages/audition_video_submission_page.dart';
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
              home: const _ScenolyticsHome(),
            );
          },
        ),
      ),
    );
  }
}

enum _ShellPage {
  actorSubmission,
  directorRankings,
}

class _ScenolyticsHome extends StatefulWidget {
  const _ScenolyticsHome();

  @override
  State<_ScenolyticsHome> createState() => _ScenolyticsHomeState();
}

class _ScenolyticsHomeState extends State<_ScenolyticsHome> {
  _ShellPage _page = _ShellPage.actorSubmission;
  final List<ActorAuditionSubmission> _submissions =
      List<ActorAuditionSubmission>.from(kMockAuditionSubmissions);
  static const String _mockLoggedInActorName = 'Alex Carter';
  static const int _mockLoggedInActorAge = 27;
  static const String _mockAuditionTheme = 'Drama / Comedy';
  static const String _mockDirectorName = 'Ava Sinclair';

  void _goTo(_ShellPage page) {
    if (_page == page) return;
    setState(() => _page = page);
  }

  void _addSubmission(ActorAuditionSubmission submission) {
    setState(() {
      _submissions.add(submission);
    });
  }

  @override
  Widget build(BuildContext context) {
    final body = switch (_page) {
      _ShellPage.actorSubmission => AuditionVideoSubmissionPage(
          onSubmitted: _addSubmission,
          loggedInActorName: _mockLoggedInActorName,
          loggedInActorAge: _mockLoggedInActorAge,
          auditionTitle: kMockAuditionTitle,
          auditionTheme: _mockAuditionTheme,
          directorName: _mockDirectorName,
          submissionCount: _submissions.length,
          auditionWindowLabel: 'Closes in 4 days',
          slotLengthLabel: '2 min max',
        ),
      _ShellPage.directorRankings => AuditionRankingsPage(submissions: _submissions),
    };

    final pageTitle = switch (_page) {
      _ShellPage.actorSubmission => 'Actor portal',
      _ShellPage.directorRankings => 'Director portal',
    };

    final currentRouteName = switch (_page) {
      _ShellPage.actorSubmission => 'submit-video',
      _ShellPage.directorRankings => 'rankings',
    };

    return MainShell(
      pageTitle: pageTitle,
      currentRouteName: currentRouteName,
      body: body,
      onSelectHome: () => _goTo(_ShellPage.actorSubmission),
      onSelectRankings: () => _goTo(_ShellPage.directorRankings),
      onSelectSubmitVideo: () => _goTo(_ShellPage.actorSubmission),
    );
  }
}
