import 'package:flutter/material.dart';

import '../pages/profile_page.dart';
import '../pages/settings_page.dart';
import '../theme/scenolytics_colors.dart';

enum _AccountAction { profile, settings, help, logout }

/// Phone: opens [ProfilePage]. Wide / web-style: popup with Profile, Settings, Help, Log out.
class AccountMenuButton extends StatelessWidget {
  const AccountMenuButton({super.key, required this.usePopupMenu});

  /// `true` when layout is wide (inline nav) — show a dropdown menu.
  final bool usePopupMenu;

  static void openProfile(BuildContext context) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const ProfilePage()),
    );
  }

  static void openSettings(BuildContext context) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const SettingsPage()),
    );
  }

  static Future<void> confirmLogOut(BuildContext context) async {
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Log out will connect to your auth service later.'),
        ),
      );
    }
  }

  void _handleAction(BuildContext context, _AccountAction action) {
    switch (action) {
      case _AccountAction.profile:
        openProfile(context);
      case _AccountAction.settings:
        openSettings(context);
      case _AccountAction.help:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Help & support — coming soon.')),
        );
      case _AccountAction.logout:
        confirmLogOut(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!usePopupMenu) {
      return IconButton.filledTonal(
        onPressed: () => openProfile(context),
        tooltip: 'Profile',
        style: IconButton.styleFrom(
          backgroundColor: ScenolyticsColors.primaryContainer,
          foregroundColor: ScenolyticsColors.onPrimaryContainer,
        ),
        icon: const Icon(Icons.person_rounded),
      );
    }

    return PopupMenuButton<_AccountAction>(
      tooltip: 'Account',
      offset: const Offset(0, 44),
      position: PopupMenuPosition.under,
      color: ScenolyticsColors.surfaceCard,
      elevation: 8,
      shadowColor: ScenolyticsColors.primary.withValues(alpha: 0.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: ScenolyticsColors.outlineSoft.withValues(alpha: 0.6),
        ),
      ),
      onSelected: (action) => _handleAction(context, action),
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: _AccountAction.profile,
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              Icons.person_outline_rounded,
              color: ScenolyticsColors.primary,
            ),
            title: Text('Profile'),
          ),
        ),
        const PopupMenuItem(
          value: _AccountAction.settings,
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              Icons.settings_outlined,
              color: ScenolyticsColors.primary,
            ),
            title: Text('Settings'),
          ),
        ),
        const PopupMenuItem(
          value: _AccountAction.help,
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              Icons.help_outline_rounded,
              color: ScenolyticsColors.primary,
            ),
            title: Text('Help'),
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: _AccountAction.logout,
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(
              Icons.logout_rounded,
              color: ScenolyticsColors.error,
            ),
            title: Text(
              'Log out',
              style: TextStyle(
                color: ScenolyticsColors.error,
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
            color: ScenolyticsColors.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.person_rounded,
                color: ScenolyticsColors.onPrimaryContainer,
                size: 22,
              ),
              Icon(
                Icons.arrow_drop_down_rounded,
                color: ScenolyticsColors.onPrimaryContainer,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
