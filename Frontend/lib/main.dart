import 'dart:developer' as developer;

import 'package:flutter/material.dart';

import 'config/app_env.dart';
import 'data/api/casting_api.dart';
import 'data/api/user_management_api.dart';
import 'data/repositories/auditions_repository.dart';
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
  const ScenolyticsApp({super.key, required this.themeController, this.logo});

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

enum _ShellPage { actorSubmission, directorRankings }

class _ScenolyticsHome extends StatefulWidget {
  const _ScenolyticsHome();

  @override
  State<_ScenolyticsHome> createState() => _ScenolyticsHomeState();
}

class _ScenolyticsHomeState extends State<_ScenolyticsHome> {
  _ShellPage _page = _ShellPage.actorSubmission;
  final List<ActorAuditionSubmission> _submissions =
      <ActorAuditionSubmission>[];
  late final AuditionsRepository _auditionsRepository;
  String _rankingsAuditionTitle = '';
  String _rankingsAuditionSubtitle = '';
  String? _directorDisplayName;

  @override
  void initState() {
    super.initState();
    _auditionsRepository = AuditionsRepository(
      castingApi: CastingApi(baseUrl: AppEnv.apiBaseUrl),
      userManagementApi: UserManagementApi(baseUrl: AppEnv.apiBaseUrl),
      videoPublicBase: AppEnv.videoPublicBase,
    );
    _refreshDirectorRankings();
    _loadDirectorProfileFromBackend();
  }

  Future<void> _loadDirectorProfileFromBackend() async {
    if (AppEnv.directorToken.trim().isEmpty) return;
    try {
      final profile = await _auditionsRepository.loadDirectorProfileUi(
        AppEnv.directorToken,
      );
      if (!mounted || profile == null) return;
      final name = profile.displayName;
      if (name != null && name.isNotEmpty) {
        setState(() => _directorDisplayName = name);
      }
    } catch (_) {}
  }

  void _goTo(_ShellPage page) {
    if (_page == page) return;
    setState(() => _page = page);
  }

  void _handleSubmission(ActorAuditionSubmission submission) {
    setState(() {
      _submissions.add(submission);
    });
    _refreshDirectorRankings();
  }

  Future<void> _refreshDirectorRankings() async {
    if (AppEnv.directorToken.isEmpty || AppEnv.auditionId.isEmpty) return;
    try {
      final header = await _auditionsRepository.loadRankingsAuditionHeader(
        directorToken: AppEnv.directorToken,
        auditionId: AppEnv.auditionId,
      );
      final live = await _auditionsRepository.loadDirectorLeaderboard(
        directorToken: AppEnv.directorToken,
        auditionId: AppEnv.auditionId,
      );
      if (!mounted) return;
      setState(() {
        _rankingsAuditionTitle = header.title;
        _rankingsAuditionSubtitle = header.subtitle;
        _submissions
          ..clear()
          ..addAll(live);
      });
    } catch (e, st) {
      developer.log(
        'Director rankings refresh failed',
        name: 'Scenolytics',
        error: e,
        stackTrace: st,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not load rankings (${e.runtimeType}). '
            'Check SCENO_API_BASE_URL and tokens in .env / .env.device.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = switch (_page) {
      _ShellPage.actorSubmission => AuditionVideoSubmissionPage(
        onSubmitted: _handleSubmission,
        auditionsRepository: _auditionsRepository,
        actorToken: AppEnv.actorToken,
        auditionId: AppEnv.auditionId,
      ),
      _ShellPage.directorRankings => AuditionRankingsPage(
        submissions: _submissions,
        auditionTitle: _rankingsAuditionTitle,
        auditionSubtitle: _rankingsAuditionSubtitle,
        directorDisplayName: _directorDisplayName,
        onRefresh: _refreshDirectorRankings,
      ),
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
      onSelectRankings: () {
        _goTo(_ShellPage.directorRankings);
        _refreshDirectorRankings();
      },
      onSelectSubmitVideo: () => _goTo(_ShellPage.actorSubmission),
    );
  }
}
