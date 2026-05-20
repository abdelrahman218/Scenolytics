import 'dart:developer' as developer;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'branding/app_logo_placeholder.dart';
import 'branding/scenolytics_branding.dart';
import 'config/app_env.dart';
import 'data/api/auth_api.dart';
import 'data/api/casting_api.dart';
import 'data/api/notifications_api.dart';
import 'data/api/user_management_api.dart';
import 'data/auth_controller.dart';
import 'data/auth_session_store.dart';
import 'data/notification_feed_controller.dart';
import 'data/repositories/auditions_repository.dart';
import 'data/models/auth_user.dart';
import 'models/actor_audition_submission.dart';
import 'models/audition_listing.dart';
import 'models/director_audition_card.dart';
import 'pages/audition_rankings_page.dart';
import 'pages/audition_video_submission_page.dart';
import 'pages/director_audition_creation_page.dart';
import 'pages/actor_dashboard_page.dart';
import 'pages/director_dashboard_page.dart';
import 'pages/explore_auditions_page.dart';
import 'pages/login_page.dart';
import 'pages/missed_notifications_page.dart';
import 'shell/main_shell.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';
import 'theme/theme_scope.dart';
import 'utils/is_flutter_web_chrome.dart';
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

enum _ShellPage {
  actorDashboard,
  actorExplore,
  actorSubmission,
  directorDashboard,
  directorRankings,
  directorCreateAudition,
  missedNotifies,
}

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
  /// Keeps async page state when the shell calls [setState] (profile load,
  /// rankings refresh, etc.) so the director dashboard does not reload and flash blank.
  final GlobalKey<DirectorDashboardPageState> _directorDashboardKey =
      GlobalKey<DirectorDashboardPageState>();
  final GlobalKey _actorDashboardKey = GlobalKey();
  final GlobalKey _exploreAuditionsKey = GlobalKey();

  _ShellPage _page = _ShellPage.actorExplore;
  String? _editingAuditionId;
  final List<ActorAuditionSubmission> _submissions =
      <ActorAuditionSubmission>[];
  late final AuditionsRepository _auditionsRepository;
  late final NotificationsApi _notificationsApi;
  late final NotificationFeedController _notificationFeed;
  String _rankingsAuditionTitle = '';
  String _rankingsAuditionSubtitle = '';
  String? _directorDisplayName;
  String? _actorDisplayName;

  /// Audition the actor most recently chose from Explore. Falls back to the
  /// compile-time [AppEnv.auditionId] so legacy single-audition runs still work.
  String? _selectedActorAuditionId;

  /// Audition the director most recently picked from the dashboard. Falls
  /// back to [AppEnv.auditionId] so the rankings page still has a target
  /// when the director opens it directly (e.g. via the nav button).
  String? _selectedDirectorAuditionId;

  AuthUser get _user => widget.auth.user!;

  String get _actorToken => _user.isActor ? _user.token : '';
  String get _directorToken => _user.isDirector ? _user.token : '';

  String get _activeActorAuditionId =>
      (_selectedActorAuditionId ?? '').isNotEmpty
          ? _selectedActorAuditionId!
          : AppEnv.auditionId;

  String get _activeDirectorAuditionId =>
      (_selectedDirectorAuditionId ?? '').isNotEmpty
          ? _selectedDirectorAuditionId!
          : AppEnv.auditionId;

  @override
  void initState() {
    super.initState();
    if (_user.isDirector) {
      _page = _ShellPage.directorDashboard;
    } else {
      _page = _ShellPage.actorDashboard;
    }
    _auditionsRepository = AuditionsRepository(
      castingApi: CastingApi(baseUrl: AppEnv.apiBaseUrl),
      userManagementApi: widget.userManagementApi,
      videoPublicBase: AppEnv.videoPublicBase,
    );
    _notificationsApi = NotificationsApi(baseUrl: AppEnv.apiBaseUrl);
    _notificationFeed = NotificationFeedController(api: _notificationsApi);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notificationFeed.attachJwt(_user.token);
      // Defer so the first dashboard/explore load is not reset by shell setState.
      _refreshDirectorRankings();
      _loadDirectorProfileFromBackend();
      _loadActorProfileFromBackend();
    });

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

  @override
  void dispose() {
    _notificationsApi.close();
    _notificationFeed.dispose();
    super.dispose();
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

  Future<void> _loadActorProfileFromBackend() async {
    if (!_user.isActor || _actorToken.isEmpty) return;
    try {
      final profile =
          await _auditionsRepository.loadActorProfileUi(_actorToken);
      if (!mounted || profile == null) return;
      final name = profile.displayName;
      if (name != null && name.isNotEmpty) {
        setState(() => _actorDisplayName = name);
      }
    } catch (_) {}
  }

  void _goTo(_ShellPage page) {
    if (_page == page) return;
    if (page == _ShellPage.actorDashboard && !_user.isActor) {
      return;
    }
    if (page == _ShellPage.actorExplore && !_user.isActor) {
      return;
    }
    if (page == _ShellPage.actorSubmission && !_user.isActor) {
      return;
    }
    if (page == _ShellPage.directorDashboard && !_user.isDirector) {
      return;
    }
    if (page == _ShellPage.directorRankings && !_user.isDirector) {
      return;
    }
    if (page == _ShellPage.directorCreateAudition && !_user.isDirector) {
      return;
    }
    setState(() => _page = page);
  }

  void _openMissedNotifiesDetached() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => MissedNotificationsPage(feed: _notificationFeed),
      ),
    );
  }

  void _openSubmissionForAudition(AuditionListing audition) {
    setState(() {
      _selectedActorAuditionId = audition.id;
      _page = _ShellPage.actorSubmission;
    });
  }

  void _openRankingsForCard(DirectorAuditionCard card) {
    setState(() {
      _selectedDirectorAuditionId = card.id;
      _page = _ShellPage.directorRankings;
    });
    _refreshDirectorRankings();
  }

  void _openCreateAudition() {
    setState(() {
      _editingAuditionId = null;
      _page = _ShellPage.directorCreateAudition;
    });
  }

  void _openEditAudition(DirectorAuditionCard card) {
    setState(() {
      _editingAuditionId = card.id;
      _page = _ShellPage.directorCreateAudition;
    });
  }

  void _onAuditionSaved({Map<String, dynamic>? audition}) {
    _directorDashboardKey.currentState?.refresh();
    if (_editingAuditionId != null) {
      final id = audition?['id']?.toString().trim();
      if (id != null && id.isNotEmpty && id == _editingAuditionId) {
        _refreshDirectorRankings();
      }
    }
    setState(() {
      _editingAuditionId = null;
      _page = _ShellPage.directorDashboard;
    });
  }

  void _handleSubmission(ActorAuditionSubmission submission) {
    setState(() {
      _submissions.add(submission);
    });
    _refreshDirectorRankings();
  }

  Future<void> _refreshDirectorRankings() async {
    if (!_user.isDirector || _directorToken.isEmpty) return;
    final auditionId = _activeDirectorAuditionId;
    if (auditionId.isEmpty) return;
    try {
      final header = await _auditionsRepository.loadRankingsAuditionHeader(
        directorToken: _directorToken,
        auditionId: auditionId,
      );
      final live = await _auditionsRepository.loadDirectorLeaderboard(
        directorToken: _directorToken,
        auditionId: auditionId,
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

  Future<void> _connectDirectorGoogleCalendar() async {
    if (!_user.isDirector || _directorToken.isEmpty) return;
    try {
      final url = await _auditionsRepository.fetchDirectorGoogleCalendarAuthUrl(
        directorToken: _directorToken,
      );
      final uri = Uri.parse(url);
      final ok =
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!mounted) return;
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open the browser for Google sign-in.'),
          ),
        );
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Google connection failed (${e.runtimeType}).'),
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
      _ShellPage.actorDashboard => ActorDashboardPage(
        key: _actorDashboardKey,
        auditionsRepository: _auditionsRepository,
        actorToken: _actorToken,
        actorDisplayName: _actorDisplayName,
        onOpenSubmission: _openSubmissionForAudition,
        onExploreAuditions: () => _goTo(_ShellPage.actorExplore),
      ),
      _ShellPage.actorExplore => ExploreAuditionsPage(
        key: _exploreAuditionsKey,
        auditionsRepository: _auditionsRepository,
        actorToken: _actorToken,
        onApply: _openSubmissionForAudition,
        extraAuditionIds: AppEnv.auditionId.isEmpty
            ? const <String>[]
            : <String>[AppEnv.auditionId],
      ),
      _ShellPage.actorSubmission => AuditionVideoSubmissionPage(
        onSubmitted: _handleSubmission,
        auditionsRepository: _auditionsRepository,
        actorToken: _actorToken,
        auditionId: _activeActorAuditionId,
        accountEmail: _user.email,
      ),
      _ShellPage.directorDashboard => DirectorDashboardPage(
        key: _directorDashboardKey,
        auditionsRepository: _auditionsRepository,
        directorToken: _directorToken,
        directorDisplayName: _directorDisplayName,
        onOpenRankings: _openRankingsForCard,
        onCreateAudition: _openCreateAudition,
        onEditAudition: _openEditAudition,
      ),
      _ShellPage.directorRankings => AuditionRankingsPage(
        submissions: _submissions,
        auditionTitle: _rankingsAuditionTitle,
        auditionSubtitle: _rankingsAuditionSubtitle,
        directorDisplayName: _directorDisplayName,
        onRefresh: _refreshDirectorRankings,
        directorReviewToken:
            _user.isDirector && _directorToken.isNotEmpty ? _directorToken : null,
        directorReviewAuditionId: _user.isDirector &&
                _activeDirectorAuditionId.trim().isNotEmpty
            ? _activeDirectorAuditionId
            : null,
        directorReviewRepository:
            _user.isDirector ? _auditionsRepository : null,
      ),
      _ShellPage.directorCreateAudition => DirectorAuditionCreationPage(
        key: ValueKey<String>(
          'director-audition-form-${_editingAuditionId ?? 'new'}',
        ),
        auditionsRepository: _auditionsRepository,
        directorToken: _directorToken,
        editAuditionId: _editingAuditionId,
        onAuditionCreated: (audition) {
          final id = audition['id']?.toString();
          developer.log(
            'Audition created${id != null && id.isNotEmpty ? ': $id' : ''}',
            name: 'Scenolytics',
          );
          _onAuditionSaved(audition: audition);
        },
        onAuditionUpdated: (audition) {
          developer.log(
            'Audition updated: ${audition['id'] ?? _editingAuditionId}',
            name: 'Scenolytics',
          );
          _onAuditionSaved(audition: audition);
        },
      ),
      _ShellPage.missedNotifies => MissedNotificationsPage(
        feed: _notificationFeed,
        embeddedInShell: true,
      ),
    };

    final pageTitle = switch (_page) {
      _ShellPage.actorDashboard => 'Actor dashboard',
      _ShellPage.actorExplore => 'Actor portal',
      _ShellPage.actorSubmission => 'Actor portal',
      _ShellPage.directorDashboard => 'Director dashboard',
      _ShellPage.directorRankings => 'Director portal',
      _ShellPage.directorCreateAudition =>
        _editingAuditionId != null ? 'Edit audition' : 'Create audition',
      _ShellPage.missedNotifies => 'Missed notifies',
    };

    final currentRouteName = switch (_page) {
      _ShellPage.actorDashboard => 'actor-dashboard',
      _ShellPage.actorExplore => 'explore-auditions',
      _ShellPage.actorSubmission => 'submit-video',
      _ShellPage.directorDashboard => 'director-dashboard',
      _ShellPage.directorRankings => 'rankings',
      _ShellPage.directorCreateAudition => 'create-audition',
      _ShellPage.missedNotifies => 'missed-notifies',
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
      authJwtForSettings: _user.token,
      notificationsApi: _notificationsApi,
      notificationFeed: _notificationFeed,
      showChromeAlertsBell:
          kIsWeb && isFlutterWebChrome && _user.token.isNotEmpty,
      onOpenMissedNotifiesDetached: _openMissedNotifiesDetached,
      onSelectMissedNotifiesShell: () => _goTo(_ShellPage.missedNotifies),
      onDirectorConnectGoogleCalendar:
          _user.isDirector ? _connectDirectorGoogleCalendar : null,
      onLogout: () async {
        await widget.auth.signOut();
      },
      onSelectActorDashboard:
          _user.isActor ? () => _goTo(_ShellPage.actorDashboard) : null,
      onSelectExploreAuditions:
          _user.isActor ? () => _goTo(_ShellPage.actorExplore) : null,
      onSelectHome: _user.isActor
          ? () => _goTo(_ShellPage.actorSubmission)
          : null,
      onSelectDirectorDashboard: _user.isDirector
          ? () => _goTo(_ShellPage.directorDashboard)
          : null,
      onSelectRankings: _user.isDirector
          ? () {
              _goTo(_ShellPage.directorRankings);
              _refreshDirectorRankings();
            }
          : null,
      onSelectCreateAudition:
          _user.isDirector ? _openCreateAudition : null,
      onSelectSubmitVideo:
          _user.isActor ? () => _goTo(_ShellPage.actorSubmission) : null,
    );
  }
}
