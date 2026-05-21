import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// OS notification tray when the backend delivers a new unread item (non-web).
class LocalPushNotifications {
  factory LocalPushNotifications() => _singleton;
  LocalPushNotifications._internal();
  static final LocalPushNotifications _singleton =
      LocalPushNotifications._internal();

  static const String _channelId = 'scenolytics_notifications';
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  Future<void>? _initFuture;

  Future<void> _ensureInit() {
    _initFuture ??= _bootstrap();
    return _initFuture!;
  }

  Future<void> _bootstrap() async {
    if (kIsWeb) return;

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      _channelId,
      'Notifications',
      description: 'Scenolytics alerts for submissions and invitations.',
      importance: Importance.high,
    );

    const androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = IOSInitializationSettings();
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: androidInit,
        iOS: iosInit,
      ),
    );

    final androidImplementation = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidImplementation?.createNotificationChannel(channel);
    try {
      await androidImplementation?.requestNotificationsPermission();
    } catch (e, st) {
      developer.log('Android notification permission: $e', stackTrace: st);
    }

    final iosImplementation = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    try {
      await iosImplementation?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (e, st) {
      developer.log('iOS notification permission: $e', stackTrace: st);
    }
  }

  Future<void> showNow({
    required String title,
    required String body,
    required Object idSeed,
  }) async {
    if (kIsWeb) return;

    await _ensureInit();

    final androidDetails = AndroidNotificationDetails(
      _channelId,
      'Notifications',
      channelDescription:
          'Scenolytics alerts for submissions and invitations.',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      ticker: title,
      styleInformation: BigTextStyleInformation(body),
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    final id =
        idSeed.hashCode & 0x3fffffff; // keep positive-ish for NotificationCompat
    try {
      await _plugin.show(
        id: id,
        title: title.trim().isEmpty ? 'Notification' : title.trim(),
        body: body.trim().isEmpty ? 'You have an update.' : body.trim(),
        notificationDetails: details,
      );
    } catch (e, st) {
      developer.log('Showing local notification failed: $e', stackTrace: st);
    }
  }
}
