import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Local notifications for alert rules and incidents. Safe to use from any
/// isolate (UI, foreground service, background fetch).
class PulseNotifications {
  PulseNotifications._();

  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static const _channelSound = 'pulse_alerts';
  static const _channelSilent = 'pulse_alerts_silent';

  static Future<void> init() async {
    if (_ready) return;
    try {
      await _init();
    } on Object catch (e) {
      // Without the platform plugin (tests, unsupported desktop setups) alerts
      // still log to History; only delivery is skipped.
      debugPrint('Notifications unavailable: $e');
    }
  }

  static Future<void> _init() async {
    const darwin = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_pulse'),
        iOS: darwin,
        macOS: darwin,
        linux: LinuxInitializationSettings(defaultActionName: 'Open Pulse'),
        windows: WindowsInitializationSettings(
          appName: 'Pulse',
          appUserModelId: 'com.pranta.pulse',
          guid: '6f1c2c4e-8a2b-4c61-9d5e-2b7a0f3e91c4',
        ),
      ),
    );
    if (Platform.isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelSound,
          'Alerts',
          description: 'Alert rules that fire with sound',
          importance: Importance.high,
        ),
      );
      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelSilent,
          'Alerts (silent)',
          description: 'Alert rules that fire without sound',
          importance: Importance.high,
          playSound: false,
          enableVibration: false,
        ),
      );
    }
    _ready = true;
  }

  /// Asks for permission where the OS requires it (Android 13+, Apple).
  static Future<bool> requestPermission() async {
    await init();
    if (!_ready) return false;
    if (Platform.isAndroid) {
      return await _plugin
              .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
              ?.requestNotificationsPermission() ??
          false;
    }
    if (Platform.isIOS) {
      return await _plugin
              .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
              ?.requestPermissions(alert: true, sound: true, badge: true) ??
          false;
    }
    if (Platform.isMacOS) {
      return await _plugin
              .resolvePlatformSpecificImplementation<MacOSFlutterLocalNotificationsPlugin>()
              ?.requestPermissions(alert: true, sound: true, badge: true) ??
          false;
    }
    return true;
  }

  static Future<void> show({
    required int id,
    required String title,
    required String body,
    bool sound = true,
  }) async {
    await init();
    if (!_ready) return;
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          sound ? _channelSound : _channelSilent,
          sound ? 'Alerts' : 'Alerts (silent)',
          importance: Importance.high,
          priority: Priority.high,
          playSound: sound,
          color: const Color(0xFFE8612C),
          category: AndroidNotificationCategory.alarm,
        ),
        iOS: DarwinNotificationDetails(presentSound: sound, presentAlert: true, presentBanner: true),
        macOS: DarwinNotificationDetails(presentSound: sound, presentAlert: true, presentBanner: true),
        linux: LinuxNotificationDetails(suppressSound: !sound, urgency: LinuxNotificationUrgency.critical),
        windows: WindowsNotificationDetails(audio: sound ? null : WindowsNotificationAudio.silent()),
      ),
    );
    if (sound && !Platform.isAndroid && !Platform.isIOS) {
      // Desktop toasts can be silent by system setting; add an in-app beep.
      await SystemSound.play(SystemSoundType.alert);
    }
  }
}
