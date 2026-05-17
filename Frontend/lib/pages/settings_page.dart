import 'package:flutter/material.dart';

import '../theme/theme_scope.dart';

/// App settings (theme, and room for notifications / account later).
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = ThemeControllerScope.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shadowColor: theme.colorScheme.shadow.withValues(alpha: 0.12),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        children: [
          SwitchListTile.adaptive(
            secondary: Icon(
              Icons.dark_mode_outlined,
              color: theme.colorScheme.primary,
            ),
            title: const Text('Dark mode'),
            subtitle: const Text('Use dark theme across the app'),
            value: controller.isDarkMode,
            onChanged: (v) => controller.setDarkMode(v),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Text(
              'More settings (notifications, account, etc.) can go here.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
