import 'package:flutter/material.dart';

import '../data/api/casting_api.dart';
import '../data/api/notifications_api.dart';
import '../data/models/notification_preferences.dart';
import '../data/notification_feed_controller.dart';
import '../theme/scenolytics_colors.dart';
import '../theme/theme_controller.dart';
import '../theme/theme_scope.dart';

/// Appearance (theme), email + in-app notification routing, director Google Calendar link.
class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.authJwt,
    required this.notificationsApi,
    this.notificationFeed,
    this.onDirectorConnectGoogleCalendar,
    this.embeddedInShell = false,
  });

  final String authJwt;
  final NotificationsApi notificationsApi;
  final NotificationFeedController? notificationFeed;

  /// Opens OAuth to store Calendar credentials for Meet callbacks (directors only).
  final Future<void> Function()? onDirectorConnectGoogleCalendar;

  /// When true, rendered inside [MainShell] (no duplicate app bar).
  final bool embeddedInShell;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  static const double _maxContentWidth = 760;

  bool _busy = false;
  bool _googleBusy = false;
  String? _error;
  NotificationPreferences? _prefs;

  ThemeController get _theme => ThemeControllerScope.of(context);

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    if (widget.authJwt.trim().isEmpty) {
      setState(() => _error = 'You need an active session to edit preferences.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final fetched = await widget.notificationsApi
          .fetchPreferences(token: widget.authJwt.trim());
      if (!mounted) return;
      setState(() {
        _prefs = fetched;
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      final msg = e is ApiException
          ? e.message
          : 'Could not reach notification preferences.';
      setState(() {
        _error = msg;
        _busy = false;
      });
    }
  }

  Future<void> _persist(NotificationPreferences next) async {
    setState(() {
      _busy = true;
      _prefs = next;
      _error = null;
    });

    try {
      final saved = await widget.notificationsApi.updatePreferences(
        token: widget.authJwt.trim(),
        preferences: next,
      );
      await widget.notificationFeed?.silentRefreshPreferences();
      if (!mounted) return;
      setState(() {
        _prefs = saved;
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      final msg = e is ApiException
          ? e.message
          : 'Could not save notification preferences.';
      setState(() {
        _busy = false;
        _error = msg;
      });
      await _loadPrefs();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final brightness = theme.brightness;

    final pageBody = DecoratedBox(
      decoration: BoxDecoration(
        gradient: ScenolyticsColors.pageBackdropGradientFor(brightness),
      ),
      child: SafeArea(
        top: !widget.embeddedInShell,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _maxContentWidth),
            child: _buildBody(theme),
          ),
        ),
      ),
    );

    if (widget.embeddedInShell) {
      return pageBody;
    }

    return Scaffold(
      backgroundColor: brightness == Brightness.dark
          ? ScenolyticsColors.darkPageBackground
          : ScenolyticsColors.pageBackground,
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shadowColor: cs.shadow.withValues(alpha: 0.12),
        iconTheme: IconThemeData(color: cs.onSurface),
        actions: [
          if (_busy)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: cs.primary,
                ),
              ),
            ),
        ],
      ),
      body: pageBody,
    );
  }

  Widget _buildBody(ThemeData theme) {
    final cs = theme.colorScheme;

    if (_error != null && _prefs == null) {
      return ListView(
        padding: const EdgeInsets.all(20),
        physics: const BouncingScrollPhysics(),
        children: [
          const SizedBox(height: 24),
          _SettingsSectionCard(
            icon: Icons.warning_amber_rounded,
            iconColor: theme.colorScheme.error,
            title: 'Something went wrong',
            subtitle: _error!,
            child: FilledButton.icon(
              onPressed: _busy ? null : _loadPrefs,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ),
        ],
      );
    }

    if (_busy && _prefs == null) {
      return Center(
        child: SizedBox(
          width: 36,
          height: 36,
          child: CircularProgressIndicator(color: cs.primary),
        ),
      );
    }

    final prefs = _prefs;

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        const _HeroBanner(),
        const SizedBox(height: 18),
        _SettingsSectionCard(
          icon: Icons.palette_outlined,
          title: 'Appearance',
          subtitle: 'Pick a theme that matches your workspace.',
          child: _ThemedSwitch(
            icon: Icons.dark_mode_outlined,
            title: 'Dark mode',
            subtitle: 'Use dark theme across the app',
            value: _theme.isDarkMode,
            onChanged: (v) => _theme.setDarkMode(v),
          ),
        ),
        if (widget.onDirectorConnectGoogleCalendar != null) ...[
          const SizedBox(height: 14),
          _SettingsSectionCard(
            icon: Icons.video_camera_front_outlined,
            title: 'Director calendar',
            subtitle:
                'Optional: link Google Calendar to generate Meet links for callbacks.',
            child: _GoogleCalendarButton(
              busy: _googleBusy,
              disabled: _busy,
              onTap: () async {
                setState(() => _googleBusy = true);
                try {
                  await widget.onDirectorConnectGoogleCalendar!.call();
                } finally {
                  if (mounted) setState(() => _googleBusy = false);
                }
              },
            ),
          ),
        ],
        if (prefs != null) ...[
          const SizedBox(height: 14),
          _SettingsSectionCard(
            icon: Icons.notifications_active_outlined,
            title: 'Notifications',
            subtitle:
                'Tune how invitations and submissions reach you (mirrors the Notification Service REST API).',
            child: Column(
              children: [
                _ThemedSwitch(
                  icon: Icons.smartphone_rounded,
                  title: 'In-app · submission updates',
                  subtitle: 'Live surfaces + mobile indicators',
                  value: prefs.inAppSubmissionNotifications,
                  onChanged: _busy || widget.authJwt.isEmpty
                      ? null
                      : (v) => _persist(
                          prefs.copyWith(inAppSubmissionNotifications: v)),
                ),
                const _SoftDivider(),
                _ThemedSwitch(
                  icon: Icons.celebration_outlined,
                  title: 'In-app · invitations',
                  subtitle: 'Casting prompts that need your reply',
                  value: prefs.inAppInvitationNotifications,
                  onChanged: _busy || widget.authJwt.isEmpty
                      ? null
                      : (v) => _persist(
                          prefs.copyWith(inAppInvitationNotifications: v)),
                ),
                const _SoftDivider(),
                _ThemedSwitch(
                  icon: Icons.forward_to_inbox_rounded,
                  title: 'Email · submission updates',
                  subtitle: 'Mirrors SMTP delivery preferences',
                  value: prefs.emailSubmissionNotifications,
                  onChanged: _busy || widget.authJwt.isEmpty
                      ? null
                      : (v) => _persist(
                          prefs.copyWith(emailSubmissionNotifications: v)),
                ),
                const _SoftDivider(),
                _ThemedSwitch(
                  icon: Icons.mark_email_read_outlined,
                  title: 'Email · invitations',
                  subtitle: 'Audition invites forwarded to inbox',
                  value: prefs.emailInvitationNotifications,
                  onChanged: _busy || widget.authJwt.isEmpty
                      ? null
                      : (v) => _persist(
                          prefs.copyWith(emailInvitationNotifications: v)),
                ),
              ],
            ),
          ),
        ],
        if (_error != null && _prefs != null) ...[
          const SizedBox(height: 14),
          _InlineError(message: _error!),
        ],
      ],
    );
  }
}

class _HeroBanner extends StatelessWidget {
  const _HeroBanner();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final b = theme.brightness;
    const onHero = ScenolyticsColors.onPrimary;

    return Container(
      decoration: BoxDecoration(
        gradient: ScenolyticsColors.heroBarGradientFor(b),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: onHero.withValues(alpha: ScenolyticsColors.heroBorderAlpha(b)),
        ),
        boxShadow: [
          BoxShadow(
            color: ScenolyticsColors.heroGradientStart.withValues(
              alpha: ScenolyticsColors.heroGlowShadowAlpha(b),
            ),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: onHero.withValues(alpha: 0.18),
              border: Border.all(
                color: onHero.withValues(alpha: 0.42),
                width: 2,
              ),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.tune_rounded,
              color: onHero,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Settings',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: onHero,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Personalize how Scenolytics looks and reaches out.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: onHero.withValues(alpha: 0.88),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsSectionCard extends StatelessWidget {
  const _SettingsSectionCard({
    required this.icon,
    required this.title,
    required this.child,
    this.subtitle,
    this.iconColor,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget child;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final cs = theme.colorScheme;
    final accent = iconColor ?? cs.primary;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: ScenolyticsColors.cardSheenFor(brightness),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: ScenolyticsColors.outlineSoftFor(brightness)
              .withValues(alpha: 0.55),
        ),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(
              alpha: brightness == Brightness.dark ? 0.28 : 0.08,
            ),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: accent.withValues(alpha: 0.22),
                    ),
                  ),
                  child: Icon(icon, color: accent, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: cs.onSurface,
                        ),
                      ),
                      if (subtitle != null && subtitle!.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          subtitle!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

class _ThemedSwitch extends StatelessWidget {
  const _ThemedSwitch({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final disabled = onChanged == null;

    return Opacity(
      opacity: disabled ? 0.6 : 1,
      child: InkWell(
        onTap: disabled ? null : () => onChanged!(!value),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          child: Row(
            children: [
              Icon(icon, color: cs.primary, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Switch.adaptive(
                value: value,
                onChanged: onChanged,
                activeThumbColor: ScenolyticsColors.onPrimary,
                activeTrackColor: ScenolyticsColors.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SoftDivider extends StatelessWidget {
  const _SoftDivider();

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
      child: Container(
        height: 1,
        color: ScenolyticsColors.outlineSoftFor(brightness)
            .withValues(alpha: 0.45),
      ),
    );
  }
}

class _GoogleCalendarButton extends StatelessWidget {
  const _GoogleCalendarButton({
    required this.busy,
    required this.disabled,
    required this.onTap,
  });

  final bool busy;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    const onHero = ScenolyticsColors.onPrimary;
    final canTap = !disabled && !busy;

    return Opacity(
      opacity: canTap ? 1 : 0.7,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: ScenolyticsColors.heroBarGradientFor(brightness),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: ScenolyticsColors.primary.withValues(
                alpha: brightness == Brightness.dark ? 0.35 : 0.25,
              ),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: canTap ? onTap : null,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(vertical: 13, horizontal: 18),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (busy)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: onHero,
                      ),
                    )
                  else
                    const Icon(
                      Icons.video_camera_front_outlined,
                      color: onHero,
                    ),
                  const SizedBox(width: 10),
                  Text(
                    busy ? 'Opening Google…' : 'Connect Google Calendar',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: onHero,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.errorContainer.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.error.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, color: cs.error, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: cs.onErrorContainer,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
