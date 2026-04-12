import 'package:flutter/material.dart';

import '../branding/scenolytics_branding.dart';
import '../theme/scenolytics_colors.dart';
import '../widgets/account_menu_button.dart';

class ScenolyticsAppDrawer extends StatelessWidget {
  const ScenolyticsAppDrawer({super.key, this.currentRouteName});

  final String? currentRouteName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final logo = ScenolyticsBranding.of(context).logo;

    return Drawer(
      backgroundColor: theme.colorScheme.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DrawerHeader(
              margin: EdgeInsets.zero,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              decoration: const BoxDecoration(
                gradient: ScenolyticsColors.heroBarGradient,
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
            _DrawerTile(
              icon: Icons.home_outlined,
              label: 'Home',
              selected: currentRouteName == 'home',
              onTap: () => Navigator.pop(context),
            ),
            _DrawerTile(
              icon: Icons.leaderboard_outlined,
              label: 'Audition rankings',
              selected: currentRouteName == 'rankings',
              onTap: () => Navigator.pop(context),
            ),
            _DrawerTile(
              icon: Icons.groups_outlined,
              label: 'Casting',
              selected: false,
              onTap: () => Navigator.pop(context),
            ),
            _DrawerTile(
              icon: Icons.settings_outlined,
              label: 'Settings',
              selected: false,
              onTap: () {
                Navigator.pop(context);
                AccountMenuButton.openSettings(context);
              },
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Scenolytics',
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
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
      leading: Icon(
        icon,
        color: selected ? cs.primary : cs.onSurfaceVariant,
      ),
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
