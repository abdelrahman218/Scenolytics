import 'dart:developer' as developer;

import 'package:flutter/material.dart';

import 'branding/app_logo_placeholder.dart';
import 'branding/scenolytics_branding.dart';
import 'config/app_env.dart';
import 'data/api/auth_api.dart';
import 'data/api/casting_api.dart';
import 'data/api/user_management_api.dart';
import 'data/auth_controller.dart';
import 'data/auth_session_store.dart';
import 'data/repositories/auditions_repository.dart';
import 'data/models/auth_user.dart';
import 'models/actor_audition_submission.dart';
import 'pages/audition_rankings_page.dart';
import 'pages/audition_video_submission_page.dart';
import 'pages/login_page.dart';
import 'shell/main_shell.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';
import 'theme/theme_scope.dart';
import 'widgets/account_menu_button.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final themeController = ThemeController();
  await themeController.load();
  final userManagementApi = UserManagementApi(baseUrl: AppEnv.apiBaseUrl);
  final auth = AuthController(
    store: const AuthSessionStore(),
    api: AuthApi(baseUrl: AppEnv.apiBaseUrl),
    userManagementApi: userManagementApi,
  );
  await auth.hydrate();
  runApp(
    ScenolyticsApp(
      themeController: themeController,
      auth: auth,
      userManagementApi: userManagementApi,
      logo: const ScenolyticsThemeAwareLogo(),
    ),
  );
}

class ScenolyticsApp extends StatelessWidget {
  const ScenolyticsApp({
    super.key,
    required this.themeController,
    required this.auth,
    required this.userManagementApi,
    this.logo,
  });

  final ThemeController themeController;
  final AuthController auth;
  final UserManagementApi userManagementApi;
  final Widget? logo;

  @override
  Widget build(BuildContext context) {
    return ThemeControllerScope(
      controller: themeController,
      child: ScenolyticsBranding(
        logo: logo ?? const ScenolyticsThemeAwareLogo(),
        child: ListenableBuilder(
          listenable: Listenable.merge(<Listenable>[themeController, auth]),
          builder: (context, _) {
            return MaterialApp(
              title: 'Scenolytics',
              debugShowCheckedModeBanner: false,
              theme: buildScenolyticsTheme(),
              darkTheme: buildScenolyticsDarkTheme(),
              themeMode: themeController.themeMode,
              home: auth.isAuthenticated
                  ? _ScenolyticsHome(
                      auth: auth,
                      userManagementApi: userManagementApi,
                    )
                  : LoginPage(auth: auth),
            );
          },
        ),
      ),
    );
  }
}

enum _ShellPage { actorSubmission, directorRankings }

class _ScenolyticsHome extends StatefulWidget {
  const _ScenolyticsHome({
    required this.auth,
    required this.userManagementApi,
  });

  final AuthController auth;
  final UserManagementApi userManagementApi;

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

  AuthUser get _user => widget.auth.user!;

  String get _actorToken => _user.isActor ? _user.token : '';
  String get _directorToken => _user.isDirector ? _user.token : '';

  @override
  void initState() {
    super.initState();
    if (_user.isDirector) {
      _page = _ShellPage.directorRankings;
    } else {
      _page = _ShellPage.actorSubmission;
    }
    _auditionsRepository = AuditionsRepository(
      castingApi: CastingApi(baseUrl: AppEnv.apiBaseUrl),
      userManagementApi: widget.userManagementApi,
      videoPublicBase: AppEnv.videoPublicBase,
    );
    _refreshDirectorRankings();
    _loadDirectorProfileFromBackend();

    if (widget.auth.consumeJustSignedUpFlag()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        AccountMenuButton.openProfile(
          context,
          user: _user,
          userManagementApi: widget.userManagementApi,
          email: _user.email,
          roleLabel: _roleLabel(),
        );
      });
    }
  }

  Future<void> _loadDirectorProfileFromBackend() async {
    if (!_user.isDirector || _directorToken.isEmpty) return;
    try {
      final profile = await _auditionsRepository.loadDirectorProfileUi(
        _directorToken,
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
    if (page == _ShellPage.actorSubmission && !_user.isActor) {
      return;
    }
    if (page == _ShellPage.directorRankings && !_user.isDirector) {
      return;
    }
    setState(() => _page = page);
  }

  void _handleSubmission(ActorAuditionSubmission submission) {
    setState(() {
      _submissions.add(submission);
    });
    _refreshDirectorRankings();
  }

  Future<void> _refreshDirectorRankings() async {
    if (!_user.isDirector || _directorToken.isEmpty || AppEnv.auditionId.isEmpty) {
      return;
    }
    try {
      final header = await _auditionsRepository.loadRankingsAuditionHeader(
        directorToken: _directorToken,
        auditionId: AppEnv.auditionId,
      );
      final live = await _auditionsRepository.loadDirectorLeaderboard(
        directorToken: _directorToken,
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
            'Check SCENO_API_BASE_URL and SCENO_AUDITION_ID.',
          ),
        ),
      );
    }
  }

  String _roleLabel() {
    switch (_user.role) {
      case 'director':
        return 'Director';
      case 'actor':
        return 'Actor';
      default:
        return _user.role;
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = switch (_page) {
      _ShellPage.actorSubmission => AuditionVideoSubmissionPage(
        onSubmitted: _handleSubmission,
        auditionsRepository: _auditionsRepository,
        actorToken: _actorToken,
        auditionId: AppEnv.auditionId,
        accountEmail: _user.email,
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
      showActorNav: _user.isActor,
      showDirectorNav: _user.isDirector,
      accountEmail: _user.email,
      accountRoleLabel: _roleLabel(),
      authUser: _user,
      userManagementApi: widget.userManagementApi,
      onLogout: () async {
        await widget.auth.signOut();
      },
      onSelectHome: _user.isActor
          ? () => _goTo(_ShellPage.actorSubmission)
          : null,
      onSelectRankings: _user.isDirector
          ? () {
              _goTo(_ShellPage.directorRankings);
              _refreshDirectorRankings();
            }
          : null,
      onSelectSubmitVideo:
          _user.isActor ? () => _goTo(_ShellPage.actorSubmission) : null,
    );
  }
}
