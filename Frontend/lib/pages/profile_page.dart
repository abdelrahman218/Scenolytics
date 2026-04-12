import 'package:flutter/material.dart';

import '../theme/scenolytics_colors.dart';

/// Director / user profile (template until backend is connected).
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: ScenolyticsColors.pageBackground,
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: ScenolyticsColors.surfaceCard,
        foregroundColor: ScenolyticsColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shadowColor: ScenolyticsColors.primary.withValues(alpha: 0.12),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          CircleAvatar(
            radius: 48,
            backgroundColor: ScenolyticsColors.primaryContainer,
            child: Icon(Icons.person_rounded, size: 52, color: ScenolyticsColors.primary),
          ),
          const SizedBox(height: 16),
          Text(
            'Your name',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Director',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: ScenolyticsColors.textMuted),
          ),
          const SizedBox(height: 28),
          Text(
            'Replace this screen with real profile fields when your API is ready.',
            style: theme.textTheme.bodyMedium?.copyWith(color: ScenolyticsColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
