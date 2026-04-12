import 'package:flutter/material.dart';

import '../theme/scenolytics_colors.dart';

/// App settings placeholder.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ScenolyticsColors.pageBackground,
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: ScenolyticsColors.surfaceCard,
        foregroundColor: ScenolyticsColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shadowColor: ScenolyticsColors.primary.withValues(alpha: 0.12),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Settings will go here (notifications, theme, account, etc.).',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: ScenolyticsColors.textSecondary,
                ),
          ),
        ),
      ),
    );
  }
}
