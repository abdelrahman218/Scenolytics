import 'package:flutter/material.dart';

import '../data/api/casting_api.dart';
import '../data/api/notifications_api.dart';
import '../data/models/notification_preferences.dart';
import '../data/notification_feed_controller.dart';
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
  });

  final String authJwt;
  final NotificationsApi notificationsApi;
  final NotificationFeedController? notificationFeed;

  /// Opens OAuth to store Calendar credentials for Meet callbacks (directors only).
  final Future<void> Function()? onDirectorConnectGoogleCalendar;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
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
      final fetched =
          await widget.notificationsApi.fetchPreferences(token: widget.authJwt.trim());
      if (!mounted) return;
      setState(() {
        _prefs = fetched;
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      final msg =
          e is ApiException ? e.message : 'Could not reach notification preferences.';
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
      final msg =
          e is ApiException ? e.message : 'Could not save notification preferences.';
      setState(() {
        _busy = false;
        _error = msg;
      });
      await _loadPrefs();
    }
  }

  Widget _preferenceBlock(ThemeData theme, NotificationPreferences p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          child: Text(
            'Notifications',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 14),
          child: Text(
            'Tune how invitations and submissions reach you '
            '(this mirrors the Notification Service REST API).',
            style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.35,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),

        AnimatedOpacity(
          duration: const Duration(milliseconds: 220),
          opacity: _busy ? 0.6 : 1,
          curve: Curves.easeOutCubic,
          child: Column(
            children: [
              SwitchListTile.adaptive(
                secondary: Icon(Icons.smartphone_rounded,
                    color: theme.colorScheme.primary),
                title: const Text('In-app · submission updates'),
                subtitle: const Text('Live surfaces + mobile indicators'),
                value: p.inAppSubmissionNotifications,
                onChanged: _busy || widget.authJwt.isEmpty
                    ? null
                    : (bool v) {
                        _persist(
                          p.copyWith(inAppSubmissionNotifications: v),
                        );
                      },
              ),
              const Divider(height: 1),
              SwitchListTile.adaptive(
                secondary: Icon(Icons.celebration_outlined,
                    color: theme.colorScheme.primary),
                title: const Text('In-app · invitations'),
                subtitle: const Text('Casting prompts that need your reply'),
                value: p.inAppInvitationNotifications,
                onChanged: _busy || widget.authJwt.isEmpty
                    ? null
                    : (bool v) {
                        _persist(
                          p.copyWith(inAppInvitationNotifications: v),
                        );
                      },
              ),
              const Divider(height: 1),
              SwitchListTile.adaptive(
                secondary: Icon(Icons.forward_to_inbox_rounded,
                    color: theme.colorScheme.primary),
                title: const Text('Email · submission updates'),
                subtitle: const Text('Mirrors SMTP delivery preferences'),
                value: p.emailSubmissionNotifications,
                onChanged: _busy || widget.authJwt.isEmpty
                    ? null
                    : (bool v) {
                        _persist(p.copyWith(emailSubmissionNotifications: v));
                      },
              ),
              const Divider(height: 1),
              SwitchListTile.adaptive(
                secondary:
                    Icon(Icons.mark_email_read_outlined, color: theme.colorScheme.primary),
                title: const Text('Email · invitations'),
                subtitle: const Text('Audition invites forwarded to inbox'),
                value: p.emailInvitationNotifications,
                onChanged: _busy || widget.authJwt.isEmpty
                    ? null
                    : (bool v) {
                        _persist(p.copyWith(emailInvitationNotifications: v));
                      },
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shadowColor: theme.colorScheme.shadow.withValues(alpha: 0.12),
        actions: [
          if (_busy)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: 1,
                child: SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeIn,
        layoutBuilder:
            (Widget? currentChild, List<Widget> previousChildren) {
          return Stack(
            alignment: Alignment.center,
            children: <Widget>[
              ...previousChildren,
              if (currentChild != null) currentChild,
            ],
          );
        },
        child: _buildBody(theme),
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_error != null && _prefs == null) {
      return ListView(
        key: const ValueKey<Object>('prefs-error'),
        padding: const EdgeInsets.all(20),
        children: [
          Icon(Icons.warning_amber_rounded,
              size: 48, color: theme.colorScheme.error),
          const SizedBox(height: 12),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _loadPrefs,
            child: const Text('Try again'),
          ),
        ],
      );
    }

    if (_busy && _prefs == null) {
      return Center(
        key: const ValueKey<Object>('busy'),
        child: SizedBox(
          width: 36,
          height: 36,
          child: CircularProgressIndicator(color: theme.colorScheme.primary),
        ),
      );
    }

    final prefs = _prefs;

    final listChildren = <Widget>[
      AnimatedOpacity(
        key: const ValueKey<Object>('appearance-block'),
        opacity: prefs == null ? 0 : 1,
        duration: const Duration(milliseconds: 180),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
          child: AnimatedSlide(
            duration: const Duration(milliseconds: 220),
            offset: prefs == null ? const Offset(0, 0.02) : Offset.zero,
            curve: Curves.easeOutCubic,
            child: SwitchListTile.adaptive(
              secondary: Icon(Icons.dark_mode_outlined,
                  color: theme.colorScheme.primary),
              title: const Text('Dark mode'),
              subtitle: const Text('Use dark theme across the app'),
              value: _theme.isDarkMode,
              onChanged: (bool v) => _theme.setDarkMode(v),
            ),
          ),
        ),
      ),
      const Divider(height: 1),
    ];

    if (widget.onDirectorConnectGoogleCalendar != null) {
      listChildren.addAll([
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
          child: Text(
            'Director calendar',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 12),
          child: Text(
            'Link Google Calendar so accepting an actor can create a Meet room '
            'and invite.',
            style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.35,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: FilledButton.icon(
            onPressed: (_busy || _googleBusy)
                ? null
                : () async {
                    setState(() => _googleBusy = true);
                    try {
                      await widget.onDirectorConnectGoogleCalendar!.call();
                    } finally {
                      if (mounted) setState(() => _googleBusy = false);
                    }
                  },
            icon: _googleBusy
                ? SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: theme.colorScheme.onPrimary,
                    ),
                  )
                : const Icon(Icons.video_camera_front_outlined),
            label: Text(_googleBusy ? 'Opening Google…' : 'Connect Google Calendar'),
          ),
        ),
        const Divider(height: 1),
      ]);
    }

    if (prefs != null) {
      listChildren.add(_preferenceBlock(theme, prefs));
    }

    return ListView(
      key: const ValueKey<Object>('prefs-ok'),
      padding: const EdgeInsets.symmetric(vertical: 6),
      physics: const BouncingScrollPhysics(),
      children: listChildren,
    );
  }
}
