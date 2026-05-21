import 'package:flutter/material.dart';

import '../data/api/notifications_api.dart';
import '../data/api/user_management_api.dart';
import '../data/models/auth_user.dart';
import '../data/notification_feed_controller.dart';
import '../pages/profile_page.dart';
import '../pages/settings_page.dart';

enum _AccountAction { profile, settings, logout }

/// Phone: opens [ProfilePage]. Wide / web-style: popup with Profile, Settings, Help, Log out.
class AccountMenuButton extends StatelessWidget {
  const AccountMenuButton({
    super.key,
    required this.usePopupMenu,
    this.authJwtForSettings,
    this.notificationsApi,
    this.notificationFeed,
    this.userEmail,
    this.accountRoleLabel,
    this.authUser,
    this.userManagementApi,
    this.onLogOut,
    this.onDirectorConnectGoogleCalendar,
    this.onSelectProfile,
    this.onSelectSettings,
  });

  /// `true` when layout is wide (inline nav) — show a dropdown menu.
  final bool usePopupMenu;

  /// Session token for authenticated notification preference APIs when opening Settings.
  final String? authJwtForSettings;
  final NotificationsApi? notificationsApi;
  final NotificationFeedController? notificationFeed;
  final String? userEmail;
  final String? accountRoleLabel;
  final AuthUser? authUser;
  final UserManagementApi? userManagementApi;
  final Future<void> Function()? onLogOut;
  final Future<void> Function()? onDirectorConnectGoogleCalendar;

  /// When set, opens profile inside [MainShell] instead of a full-screen route.
  final VoidCallback? onSelectProfile;

  /// When set, opens settings inside [MainShell] instead of a full-screen route.
  final VoidCallback? onSelectSettings;

  static void openProfile(
    BuildContext context, {
    String? email,
    String? roleLabel,
    AuthUser? user,
    UserManagementApi? userManagementApi,
  }) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ProfilePage(
          user: user,
          userManagementApi: userManagementApi,
          userEmail: email,
          accountRoleLabel: roleLabel,
        ),
      ),
    );
  }

  static void openSettings(
    BuildContext context, {
    required String authJwt,
    required NotificationsApi notificationsApi,
    NotificationFeedController? notificationFeed,
    Future<void> Function()? onDirectorConnectGoogleCalendar,
  }) {
    final jwt = authJwt.trim();
    if (jwt.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Sign in again to adjust notification routing preferences.'),
        ),
      );
      return;
    }

    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => SettingsPage(
          authJwt: jwt,
          notificationsApi: notificationsApi,
          notificationFeed: notificationFeed,
          onDirectorConnectGoogleCalendar: onDirectorConnectGoogleCalendar,
        ),
      ),
    );
  }

  static Future<void> confirmLogOut(
    BuildContext context, {
    Future<void> Function()? onLogOut,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await onLogOut?.call();
    }
  }

  void _handleAction(
    BuildContext context,
    _AccountAction action, {
    String? email,
    String? roleLabel,
    AuthUser? user,
    UserManagementApi? api,
    String? jwt,
    NotificationsApi? notificationsApi,
    NotificationFeedController? notificationFeed,
    Future<void> Function()? onDirectorConnectGoogleCalendar,
    VoidCallback? onSelectProfile,
    VoidCallback? onSelectSettings,
  }) {
    switch (action) {
      case _AccountAction.profile:
        if (onSelectProfile != null) {
          onSelectProfile();
        } else {
          openProfile(
            context,
            email: email,
            roleLabel: roleLabel,
            user: user,
            userManagementApi: api,
          );
        }
      case _AccountAction.settings:
        final prefsApi = notificationsApi;
        final token = jwt?.trim() ?? '';
        if (prefsApi == null || token.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Unable to reach notification preferences right now',
              ),
            ),
          );
          return;
        }
        if (onSelectSettings != null) {
          onSelectSettings();
        } else {
          openSettings(
            context,
            authJwt: token,
            notificationsApi: prefsApi,
            notificationFeed: notificationFeed,
            onDirectorConnectGoogleCalendar: onDirectorConnectGoogleCalendar,
          );
        }
      case _AccountAction.logout:
        confirmLogOut(context, onLogOut: onLogOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (!usePopupMenu) {
      return IconButton.filledTonal(
        onPressed: () {
          if (onSelectProfile != null) {
            onSelectProfile!();
          } else {
            openProfile(
              context,
              email: userEmail,
              roleLabel: accountRoleLabel,
              user: authUser,
              userManagementApi: userManagementApi,
            );
          }
        },
        tooltip: 'Profile',
        style: IconButton.styleFrom(
          backgroundColor: cs.primaryContainer,
          foregroundColor: cs.onPrimaryContainer,
        ),
        icon: const Icon(Icons.person_rounded),
      );
    }

    return PopupMenuButton<_AccountAction>(
      tooltip: 'Account',
      offset: const Offset(0, 10),
      position: PopupMenuPosition.under,
      color: cs.surface,
      elevation: 8,
      shadowColor: cs.shadow.withValues(alpha: 0.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: cs.outline.withValues(alpha: 0.55),
        ),
      ),
      onSelected: (action) => _handleAction(
        context,
        action,
        email: userEmail,
        roleLabel: accountRoleLabel,
        user: authUser,
        api: userManagementApi,
        jwt: authJwtForSettings,
        notificationsApi: notificationsApi,
        notificationFeed: notificationFeed,
        onDirectorConnectGoogleCalendar: onDirectorConnectGoogleCalendar,
        onSelectProfile: onSelectProfile,
        onSelectSettings: onSelectSettings,
      ),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: _AccountAction.profile,
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.person_outline_rounded, color: cs.primary),
            title: const Text('Profile'),
          ),
        ),
        PopupMenuItem(
          value: _AccountAction.settings,
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.settings_outlined, color: cs.primary),
            title: const Text('Settings'),
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: _AccountAction.logout,
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.logout_rounded, color: cs.error),
            title: Text(
              'Log out',
              style: TextStyle(
                color: cs.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: cs.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.person_rounded,
                color: cs.onPrimaryContainer,
                size: 22,
              ),
              Icon(
                Icons.arrow_drop_down_rounded,
                color: cs.onPrimaryContainer,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
