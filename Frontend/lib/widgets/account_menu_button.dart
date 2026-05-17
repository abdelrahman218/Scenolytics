import 'package:flutter/material.dart';

import '../data/api/user_management_api.dart';
import '../data/models/auth_user.dart';
import '../pages/profile_page.dart';
import '../pages/settings_page.dart';

enum _AccountAction { profile, settings, help, logout }

/// Phone: opens [ProfilePage]. Wide / web-style: popup with Profile, Settings, Help, Log out.
class AccountMenuButton extends StatelessWidget {
  const AccountMenuButton({
    super.key,
    required this.usePopupMenu,
    this.userEmail,
    this.accountRoleLabel,
    this.authUser,
    this.userManagementApi,
    this.onLogOut,
  });

  /// `true` when layout is wide (inline nav) — show a dropdown menu.
  final bool usePopupMenu;
  final String? userEmail;
  final String? accountRoleLabel;
  final AuthUser? authUser;
  final UserManagementApi? userManagementApi;
  final Future<void> Function()? onLogOut;

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

  static void openSettings(BuildContext context) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const SettingsPage()),
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
  }) {
    switch (action) {
      case _AccountAction.profile:
        openProfile(
          context,
          email: email,
          roleLabel: roleLabel,
          user: user,
          userManagementApi: api,
        );
      case _AccountAction.settings:
        openSettings(context);
      case _AccountAction.help:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Help & support — coming soon.')),
        );
      case _AccountAction.logout:
        confirmLogOut(context, onLogOut: onLogOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (!usePopupMenu) {
      return IconButton.filledTonal(
        onPressed: () => openProfile(
          context,
          email: userEmail,
          roleLabel: accountRoleLabel,
          user: authUser,
          userManagementApi: userManagementApi,
        ),
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
      offset: const Offset(0, 44),
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
        PopupMenuItem(
          value: _AccountAction.help,
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.help_outline_rounded, color: cs.primary),
            title: const Text('Help'),
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
