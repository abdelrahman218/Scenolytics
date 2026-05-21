import 'dart:async';
import 'dart:collection';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../config/app_env.dart';
import 'api/notifications_api.dart';
import 'models/app_notification.dart';
import 'models/notification_preferences.dart';
import '../services/local_push_notifications.dart';

/// Live notification list + unread count backed by REST and optional Socket.IO.
class NotificationFeedController extends ChangeNotifier
    with WidgetsBindingObserver {
  NotificationFeedController({
    required NotificationsApi api,
    LocalPushNotifications? localPush,
  })  : _api = api,
        _localPush = localPush ?? LocalPushNotifications() {
    WidgetsBinding.instance.addObserver(this);
  }

  final NotificationsApi _api;
  final LocalPushNotifications _localPush;

  String _jwt = '';
  Timer? _pollTimer;
  io.Socket? _socket;

  NotificationPreferences? _preferences;
  final List<AppNotification> _notifications = <AppNotification>[];
  final Set<String> _trayEmittedIds = <String>{};
  Set<String>? _previousFetchIds;

  UnmodifiableListView<AppNotification> get notifications =>
      UnmodifiableListView<AppNotification>(_notifications);

  NotificationPreferences? get preferences => _preferences;

  int get unreadCount =>
      _notifications.where((AppNotification e) => !e.isRead).length;

  void attachJwt(String jwt) {
    final trimmed = jwt.trim();
    if (trimmed == _jwt && _notifications.isNotEmpty) {
      return;
    }
    _jwt = trimmed;
    if (_jwt.isEmpty) {
      clearLocalState();
      return;
    }

    scheduleMicrotask(() async {
      await refreshAllQuiet();
      _restartPolling();
      scheduleMicrotask(_connectSocket);
    });
  }

  void clearLocalState() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _disconnectSocket();
    _notifications.clear();
    _preferences = null;
    _previousFetchIds = null;
    _trayEmittedIds.clear();
    notifyListeners();
  }

  Future<void> refreshAllQuiet() async {
    if (_jwt.isEmpty) return;
    await Future.wait(<Future<void>>[
      silentRefreshNotifications(),
      silentRefreshPreferences(),
    ]);
  }

  Future<void> silentRefreshPreferences() async {
    if (_jwt.isEmpty) return;
    try {
      _preferences = await _api.fetchPreferences(token: _jwt);
      notifyListeners();
    } catch (e, st) {
      developer.log('Notification prefs GET failed: $e', stackTrace: st);
    }
  }

  Future<void> silentRefreshNotifications() async {
    if (_jwt.isEmpty) return;

    List<AppNotification> incoming;
    try {
      incoming = await _api.fetchNotifications(token: _jwt);
    } catch (e, st) {
      developer.log('Notification list GET failed: $e', stackTrace: st);
      return;
    }

    final previousIds = _previousFetchIds;
    incoming.sort(_sortNewestFirst);
    final nextIds = incoming.map((AppNotification e) => e.id).toSet();

    _notifications
      ..clear()
      ..addAll(incoming);

    if (!kIsWeb && previousIds != null) {
      for (final n in incoming) {
        if (!previousIds.contains(n.id) && !n.isRead) {
          _maybeTray(n);
        }
      }
    }

    _previousFetchIds = nextIds;
    notifyListeners();
  }

  static int _sortNewestFirst(AppNotification a, AppNotification b) {
    final ta = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final tb = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    return tb.compareTo(ta);
  }

  Future<void> openAndMarkRead(AppNotification notification) async {
    if (_jwt.isEmpty || notification.id.isEmpty) return;
    if (notification.isRead) return;

    final idx =
        _notifications.indexWhere((AppNotification e) => e.id == notification.id);
    if (idx < 0) return;

    try {
      final updated = await _api.markAsRead(
        token: _jwt,
        notificationId: notification.id,
      );
      _notifications[idx] = updated;
      notifyListeners();
    } catch (e, st) {
      developer.log('Mark read failed: $e', stackTrace: st);
      rethrow;
    }
  }

  void _restartPolling() {
    _pollTimer?.cancel();
    if (_jwt.isEmpty) return;
    _pollTimer =
        Timer.periodic(const Duration(seconds: 46), (_) {
      unawaited(silentRefreshNotifications());
      unawaited(silentRefreshPreferences());
    });
  }

  void _disconnectSocket() {
    try {
      _socket?.disconnect();
      _socket?.dispose();
    } catch (_) {}
    _socket = null;
  }

  void _connectSocket() {
    final uri = AppEnv.notificationSocketBaseUrl.trim();
    if (_jwt.isEmpty || uri.isEmpty) {
      _disconnectSocket();
      return;
    }

    _disconnectSocket();
    try {
      final sock = io.io(
        uri,
        io.OptionBuilder()
            .enableForceNewConnection()
            .setTransports(<String>['websocket', 'polling'])
            .setExtraHeaders(<String, String>{
              'authorization': _jwt.startsWith('Bearer ')
                  ? _jwt
                  : 'Bearer $_jwt',
            })
            .build(),
      );

      sock.onDisconnect((dynamic _) => developer.log(
            'Notifications socket disconnected',
            name: 'Scenolytics.Notify',
          ));
      sock.onConnectError((dynamic err) => developer.log(
            'Notifications socket connect error: $err',
            name: 'Scenolytics.Notify',
          ));
      sock.on('notification', _onSocketPayload);

      sock.connect();
      _socket = sock;
    } catch (e, st) {
      developer.log(
        'Socket setup failed ($e)',
        stackTrace: st,
        name: 'Scenolytics.Notify',
      );
      _disconnectSocket();
    }
  }

  void _onSocketPayload(dynamic payload) {
    Map<String, dynamic>? map;
    if (payload is Map<String, dynamic>) {
      map = payload;
    } else if (payload is Map) {
      map = Map<String, dynamic>.from(payload);
    }
    if (map == null) return;
    try {
      final n = AppNotification.fromJson(map);
      mergeIncomingLive(n);
    } catch (e, st) {
      developer.log(
        'Bad socket payload ($e)',
        stackTrace: st,
        name: 'Scenolytics.Notify',
      );
    }
  }

  void mergeIncomingLive(AppNotification n) {
    if (n.id.isEmpty) return;
    final ix = _notifications.indexWhere((AppNotification e) => e.id == n.id);
    if (ix >= 0) {
      _notifications[ix] = n;
    } else {
      _notifications.insert(0, n);
      _notifications.sort(_sortNewestFirst);
      _previousFetchIds ??= <String>{};
      _previousFetchIds!.add(n.id);
    }
    if (!kIsWeb && !n.isRead) {
      _maybeTray(n);
    }
    notifyListeners();
  }

  bool _wantsTray(AppNotification n) {
    final p = _preferences;
    if (p == null) return true;
    switch (n.notificationType) {
      case 'Submission Notification':
        return p.inAppSubmissionNotifications;
      case 'Invitation Notification':
        return p.inAppInvitationNotifications;
      default:
        return true;
    }
  }

  void _maybeTray(AppNotification n) {
    if (kIsWeb || !_wantsTray(n)) return;
    if (_trayEmittedIds.contains(n.id)) return;
    _trayEmittedIds.add(n.id);
    if (_trayEmittedIds.length > 200) {
      _trayEmittedIds.clear();
      _trayEmittedIds.add(n.id);
    }
    unawaited(_localPush.showNow(
      title: n.title,
      body: n.message,
      idSeed: n.id,
    ));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || _jwt.isEmpty) return;
    unawaited(refreshAllQuiet());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    _disconnectSocket();
    super.dispose();
  }
}
