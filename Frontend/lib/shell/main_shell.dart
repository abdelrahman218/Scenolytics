import 'package:flutter/material.dart';

import '../branding/scenolytics_branding.dart';
import '../theme/scenolytics_colors.dart';
import '../widgets/account_menu_button.dart';
import '../widgets/scenolytics_app_drawer.dart';
import '../widgets/scenolytics_footer.dart';

/// App chrome: header (logo + nav), drawer on narrow screens, footer.
class MainShell extends StatefulWidget {
  const MainShell({
    super.key,
    required this.body,
    this.pageTitle,
    this.currentRouteName = 'rankings',
  });

  final Widget body;
  final String? pageTitle;
  final String currentRouteName;

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

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: ScenolyticsColors.pageBackground,
      drawer: useDrawer
          ? ScenolyticsAppDrawer(currentRouteName: widget.currentRouteName)
          : null,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _HeaderBar(
            showMenu: useDrawer,
            onMenuPressed: () => _scaffoldKey.currentState?.openDrawer(),
            pageTitle: widget.pageTitle,
            logo: logo,
          ),
          Expanded(child: widget.body),
          const ScenolyticsFooter(),
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
    this.pageTitle,
  });

  final bool showMenu;
  final VoidCallback onMenuPressed;
  final Widget logo;
  final String? pageTitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final showInlineNav = width >= MainShell.drawerBreakpoint;

    return Material(
      elevation: 2,
      shadowColor: ScenolyticsColors.primary.withValues(alpha: 0.2),
      color: ScenolyticsColors.surfaceCard,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              if (showMenu)
                IconButton(
                  onPressed: onMenuPressed,
                  icon: const Icon(Icons.menu_rounded),
                  tooltip: 'Menu',
                  color: ScenolyticsColors.primary,
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
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: ScenolyticsColors.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              if (showInlineNav) ...[
                const SizedBox(width: 16),
                _NavButton(
                  icon: Icons.home_outlined,
                  label: 'Home',
                  onPressed: () =>
                      Navigator.of(context).popUntil((r) => r.isFirst),
                ),
                _NavButton(
                  icon: Icons.leaderboard_outlined,
                  label: 'Rankings',
                  filled: true,
                  onPressed: () =>
                      Navigator.of(context).popUntil((r) => r.isFirst),
                ),
                _NavButton(
                  icon: Icons.groups_outlined,
                  label: 'Casting',
                  onPressed: () {},
                ),
                const Spacer(),
                AccountMenuButton(usePopupMenu: true),
              ] else ...[
                const Spacer(),
                AccountMenuButton(usePopupMenu: false),
              ],
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
    final style = TextButton.styleFrom(
      foregroundColor: filled
          ? ScenolyticsColors.onPrimary
          : ScenolyticsColors.primary,
      backgroundColor: filled ? ScenolyticsColors.primary : null,
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
