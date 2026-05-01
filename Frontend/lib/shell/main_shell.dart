import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../branding/scenolytics_branding.dart';
import '../data/api/user_management_api.dart';
import '../data/models/auth_user.dart';
import '../widgets/account_menu_button.dart';
import '../widgets/scenolytics_app_drawer.dart';

/// App chrome: full-width header + drawer on narrow screens; account menu at the trailing edge.
class MainShell extends StatefulWidget {
  const MainShell({
    super.key,
    required this.body,
    this.pageTitle,
    this.currentRouteName = 'rankings',
    this.onSelectHome,
    this.onSelectRankings,
    this.onSelectSubmitVideo,
    this.showActorNav = true,
    this.showDirectorNav = true,
    this.accountEmail,
    this.accountRoleLabel,
    this.authUser,
    this.userManagementApi,
    this.onLogout,
  });

  final Widget body;
  final String? pageTitle;
  final String currentRouteName;
  final VoidCallback? onSelectHome;
  final VoidCallback? onSelectRankings;
  final VoidCallback? onSelectSubmitVideo;
  final bool showActorNav;
  final bool showDirectorNav;
  final String? accountEmail;
  final String? accountRoleLabel;
  final AuthUser? authUser;
  final UserManagementApi? userManagementApi;
  final Future<void> Function()? onLogout;

  static const double drawerBreakpoint = 760;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final useDrawer = width < MainShell.drawerBreakpoint;
    final logo = ScenolyticsBranding.of(context).logo;

    final theme = Theme.of(context);

    final edgeDrag = useDrawer
        ? math.max(
            56.0,
            MediaQuery.paddingOf(context).left + 40.0,
          )
        : null;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: theme.colorScheme.surface,
      drawer: useDrawer
          ? ScenolyticsAppDrawer(
              currentRouteName: widget.currentRouteName,
              onSelectHome: widget.onSelectHome,
              onSelectRankings: widget.onSelectRankings,
              onSelectSubmitVideo: widget.onSelectSubmitVideo,
              showActorNav: widget.showActorNav,
              showDirectorNav: widget.showDirectorNav,
            )
          : null,
      drawerEnableOpenDragGesture: useDrawer,
      drawerEdgeDragWidth: edgeDrag,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _HeaderBar(
            showMenu: useDrawer,
            onMenuPressed: () => _scaffoldKey.currentState?.openDrawer(),
            pageTitle: widget.pageTitle,
            logo: logo,
            currentRouteName: widget.currentRouteName,
            onSelectHome: widget.onSelectHome,
            onSelectRankings: widget.onSelectRankings,
            onSelectSubmitVideo: widget.onSelectSubmitVideo,
            showActorNav: widget.showActorNav,
            showDirectorNav: widget.showDirectorNav,
            accountEmail: widget.accountEmail,
            accountRoleLabel: widget.accountRoleLabel,
            authUser: widget.authUser,
            userManagementApi: widget.userManagementApi,
            onLogout: widget.onLogout,
          ),
          Expanded(child: widget.body),
        ],
      ),
    );
  }
}

class _HeaderBar extends StatelessWidget {
  const _HeaderBar({
    required this.showMenu,
    required this.onMenuPressed,
    required this.logo,
    required this.currentRouteName,
    this.onSelectHome,
    this.onSelectRankings,
    this.onSelectSubmitVideo,
    this.pageTitle,
    this.showActorNav = true,
    this.showDirectorNav = true,
    this.accountEmail,
    this.accountRoleLabel,
    this.authUser,
    this.userManagementApi,
    this.onLogout,
  });

  final bool showMenu;
  final VoidCallback onMenuPressed;
  final Widget logo;
  final String currentRouteName;
  final VoidCallback? onSelectHome;
  final VoidCallback? onSelectRankings;
  final VoidCallback? onSelectSubmitVideo;
  final String? pageTitle;
  final bool showActorNav;
  final bool showDirectorNav;
  final String? accountEmail;
  final String? accountRoleLabel;
  final AuthUser? authUser;
  final UserManagementApi? userManagementApi;
  final Future<void> Function()? onLogout;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final showInlineNav = width >= MainShell.drawerBreakpoint;

    return Material(
      elevation: 2,
      shadowColor: theme.colorScheme.shadow.withValues(alpha: 0.25),
      color: theme.colorScheme.surface,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          width: double.infinity,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (showMenu)
                        IconButton(
                          onPressed: onMenuPressed,
                          icon: const Icon(Icons.menu_rounded),
                          tooltip: 'Menu',
                          color: theme.colorScheme.primary,
                        ),
                      SizedBox(
                        height: 40,
                        child: FittedBox(
                          fit: BoxFit.contain,
                          alignment: Alignment.centerLeft,
                          child: logo,
                        ),
                      ),
                      if (pageTitle != null && pageTitle!.isNotEmpty) ...[
                        const SizedBox(width: 12),
                        Flexible(
                          child: Text(
                            pageTitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                      if (showInlineNav)
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                                child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const SizedBox(width: 16),
                                  if (showActorNav)
                                    _NavButton(
                                      icon: Icons.video_call_outlined,
                                      label: 'Actor submission',
                                      filled: currentRouteName == 'submit-video',
                                      onPressed: onSelectHome ?? () {},
                                    ),
                                  if (showDirectorNav)
                                    _NavButton(
                                      icon: Icons.leaderboard_outlined,
                                      label: 'Director rankings',
                                      filled: currentRouteName == 'rankings',
                                      onPressed: onSelectRankings ?? () {},
                                    ),
                                  _NavButton(
                                    icon: Icons.groups_outlined,
                                    label: 'Auditions',
                                    onPressed: () {},
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      else
                        const Spacer(),
                    ],
                  ),
                ),
              ),
              // Trailing inset so the account control is not flush with the viewport edge.
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 10, 8, 10),
                child: AccountMenuButton(
                  usePopupMenu: showInlineNav,
                  userEmail: accountEmail,
                  accountRoleLabel: accountRoleLabel,
                  authUser: authUser,
                  userManagementApi: userManagementApi,
                  onLogOut: onLogout,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.filled = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final style = TextButton.styleFrom(
      foregroundColor: filled ? cs.onPrimary : cs.primary,
      backgroundColor: filled ? cs.primary : null,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );

    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: TextButton.icon(
        onPressed: onPressed,
        style: style,
        icon: Icon(icon, size: 20),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }
}
