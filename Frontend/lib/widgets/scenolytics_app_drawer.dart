import 'package:flutter/material.dart';

import '../branding/app_logo_placeholder.dart';
import '../data/api/notifications_api.dart';
import '../data/notification_feed_controller.dart';
import '../theme/scenolytics_colors.dart';
import 'account_menu_button.dart';

class ScenolyticsAppDrawer extends StatelessWidget {
  const ScenolyticsAppDrawer({
    super.key,
    this.currentRouteName,
    this.onSelectHome,
    this.onSelectRankings,
    this.onSelectCreateAudition,
    this.onSelectSubmitVideo,
    this.onSelectExploreAuditions,
    this.onSelectActorDashboard,
    this.onSelectDirectorDashboard,
    this.onSelectMissedNotifies,
    this.showActorNav = true,
    this.showDirectorNav = true,
    this.onLogout,
    this.authJwtForSettings,
    this.notificationsApi,
    this.notificationFeed,
    this.onDirectorConnectGoogleCalendar,
  });

  final String? currentRouteName;
  final VoidCallback? onSelectHome;
  final VoidCallback? onSelectRankings;
  final VoidCallback? onSelectCreateAudition;
  final VoidCallback? onSelectSubmitVideo;
  final VoidCallback? onSelectExploreAuditions;
  final VoidCallback? onSelectActorDashboard;
  final VoidCallback? onSelectDirectorDashboard;
  final VoidCallback? onSelectMissedNotifies;
  final bool showActorNav;
  final bool showDirectorNav;
  final Future<void> Function()? onLogout;
  final String? authJwtForSettings;
  final NotificationsApi? notificationsApi;
  final NotificationFeedController? notificationFeed;
  final Future<void> Function()? onDirectorConnectGoogleCalendar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Hero gradient header — light mark + wordmark on blue.
    const logo = ScenolyticsThemeAwareLogo(
      height: 48,
      onHeroBackground: true,
    );
    final tapCreateAudition = onSelectCreateAudition;
    final tapExplore = onSelectExploreAuditions;
    final tapActorDashboard = onSelectActorDashboard;
    final tapDashboard = onSelectDirectorDashboard;

    final navTiles = <Widget>[
      if (showActorNav && tapActorDashboard != null)
        _DrawerTile(
          icon: Icons.dashboard_outlined,
          label: 'My dashboard',
          selected: currentRouteName == 'actor-dashboard' ||
              currentRouteName == 'submit-video',
          onTap: () {
            Navigator.pop(context);
            tapActorDashboard();
          },
        ),
      if (showActorNav && tapExplore != null)
        _DrawerTile(
          icon: Icons.explore_outlined,
          label: 'Explore auditions',
          selected: currentRouteName == 'explore-auditions',
          onTap: () {
            Navigator.pop(context);
            tapExplore();
          },
        ),
      if (showDirectorNav && tapDashboard != null)
        _DrawerTile(
          icon: Icons.dashboard_customize_outlined,
          label: 'Dashboard',
          selected: currentRouteName == 'director-dashboard' ||
              currentRouteName == 'rankings',
          onTap: () {
            Navigator.pop(context);
            tapDashboard();
          },
        ),
      if (showDirectorNav && tapCreateAudition != null)
        _DrawerTile(
          icon: Icons.add_circle_outline_rounded,
          label: 'Create audition',
          selected: currentRouteName == 'create-audition',
          onTap: () {
            Navigator.pop(context);
            tapCreateAudition();
          },
        ),
      if (onSelectMissedNotifies != null)
        _DrawerTile(
          icon: Icons.notifications_paused_rounded,
          label: 'Notifications',
          selected: currentRouteName == 'missed-notifies',
          onTap: () {
            Navigator.pop(context);
            onSelectMissedNotifies!();
          },
        ),
    ];

    return Drawer(
      backgroundColor: theme.colorScheme.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DrawerHeader(
              margin: EdgeInsets.zero,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              decoration: BoxDecoration(
                gradient: ScenolyticsColors.heroBarGradientFor(theme.brightness),
              ),
              child: Align(
                alignment: Alignment.bottomLeft,
                child: SizedBox(
                  height: 48,
                  child: FittedBox(
                    fit: BoxFit.contain,
                    alignment: Alignment.bottomLeft,
                    child: DefaultTextStyle(
                      style: const TextStyle(
                        color: ScenolyticsColors.onPrimary,
                      ),
                      child: IconTheme(
                        data: const IconThemeData(
                          color: ScenolyticsColors.onPrimary,
                        ),
                        child: logo,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: navTiles,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                'Scenolytics',
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            if (onLogout != null)
              ListTile(
                leading: Icon(Icons.logout_rounded, color: theme.colorScheme.error),
                title: Text(
                  'Log out',
                  style: TextStyle(
                    color: theme.colorScheme.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onTap: () async {
                  await AccountMenuButton.confirmLogOut(
                    context,
                    onLogOut: onLogout,
                  );
                  if (context.mounted) {
                    Navigator.of(context).maybePop();
                  }
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _DrawerTile extends StatelessWidget {
  const _DrawerTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(icon, color: selected ? cs.primary : cs.onSurfaceVariant),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? cs.primary : cs.onSurface,
        ),
      ),
      selected: selected,
      selectedTileColor: cs.primaryContainer.withValues(alpha: 0.45),
      onTap: onTap,
    );
  }
}
