import 'dart:async';
import 'dart:io';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/shared_preference_keys.dart';
import '../../data/db/app_database.dart';
import '../../data/settings_store.dart';
import '../net/lan/oui.dart';
import '../net/ping_prober.dart';
import 'monitor_engine.dart';
import 'notifications.dart';

/// Entry point of the monitoring isolate (Android foreground service,
/// iOS background refresh).
@pragma('vm:entry-point')
void pulseMonitorCallback() {
  FlutterForegroundTask.setTaskHandler(PulseMonitorTask());
}

/// Runs [MonitorEngine] cycles inside the foreground service.
class PulseMonitorTask extends TaskHandler {
  AppDatabase? _db;
  MonitorEngine? _engine;
  SharedPreferences? _prefs;
  String? _lastAlert;
  bool _cycling = false;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    WidgetsFlutterBinding.ensureInitialized();
    await PulseNotifications.init();
    _prefs = await SharedPreferences.getInstance();
    _db = AppDatabase.open();
    await OuiDb.load();
    _engine = MonitorEngine(
      db: _db!,
      prober: const PingProber(),
      settings: () => SettingsStore(_prefs!).load(),
      mutedUntil: _mutedUntil,
      onTrayAlert: (message) => _lastAlert = message,
    );
    await _cycle();
  }

  DateTime? _mutedUntil() {
    final ms = _prefs?.getInt(kAlertsMutedUntilKey);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  @override
  void onRepeatEvent(DateTime timestamp) => _cycle();

  Future<void> _cycle() async {
    final engine = _engine;
    if (engine == null || _cycling) return;
    _cycling = true;
    try {
      // Other isolates write settings; re-read them every cycle.
      await _prefs?.reload();
      final report = await engine.runCycle();
      if (Platform.isAndroid) await engine.runLanWatch();
      final text = _lastAlert != null && report.firing > 0 ? '▲ $_lastAlert' : report.summary;
      if (report.firing == 0) _lastAlert = null;
      await FlutterForegroundTask.updateService(
        notificationTitle: report.firing > 0 ? 'Pulse · alert' : 'Pulse · monitoring',
        notificationText: text,
      );
      FlutterForegroundTask.sendDataToMain({
        'at': report.at.millisecondsSinceEpoch,
        'targets': report.targets,
        'down': report.down,
        'firing': report.firing,
      });
    } on Object catch (e) {
      debugPrint('Monitor cycle failed: $e');
    } finally {
      _cycling = false;
    }
  }

  @override
  void onNotificationButtonPressed(String id) {
    if (id == 'pause') {
      _prefs?.setBool(kMonitorBackgroundKey, false);
      FlutterForegroundTask.stopService();
    }
  }

  @override
  void onNotificationPressed() => FlutterForegroundTask.launchApp(BackgroundMonitor.monitorRoute);

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    await _db?.close();
    _db = null;
  }
}

/// Starts and stops the monitoring service from the UI isolate.
class BackgroundMonitor {
  BackgroundMonitor._();

  static const monitorRoute = '/monitor';
  static const _serviceId = 4242;

  static bool get supported => Platform.isAndroid || Platform.isIOS;

  static void init({required int intervalSec}) {
    if (!supported) return;
    FlutterForegroundTask.initCommunicationPort();
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'pulse_monitor',
        channelName: 'Background monitor',
        channelDescription: 'Shown while Pulse checks your targets in the background.',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(showNotification: false, playSound: false),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(intervalSec * 1000),
        autoRunOnBoot: true,
        autoRunOnMyPackageReplaced: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  static Future<bool> get isRunning async => supported && await FlutterForegroundTask.isRunningService;

  /// Asks for the permissions a long-running monitor needs on Android.
  static Future<void> requestPermissions() async {
    if (!supported) return;
    if (await FlutterForegroundTask.checkNotificationPermission() != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }
    if (Platform.isAndroid && !await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
      await FlutterForegroundTask.requestIgnoreBatteryOptimization();
    }
  }

  static Future<void> start({required int intervalSec, required String summary}) async {
    if (!supported) return;
    init(intervalSec: intervalSec);
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.restartService();
      return;
    }
    await FlutterForegroundTask.startService(
      serviceId: _serviceId,
      serviceTypes: const [ForegroundServiceTypes.specialUse],
      notificationTitle: 'Pulse · monitoring',
      notificationText: summary,
      notificationIcon: const NotificationIcon(
        metaDataName: 'com.pranta.pulse.MONITOR_ICON',
        backgroundColor: Color(0xFFE8612C),
      ),
      notificationButtons: const [NotificationButton(id: 'pause', text: 'Pause')],
      notificationInitialRoute: monitorRoute,
      callback: pulseMonitorCallback,
    );
  }

  static Future<void> stop() async {
    if (!supported) return;
    if (await FlutterForegroundTask.isRunningService) await FlutterForegroundTask.stopService();
  }

  /// Keeps the service's notification in sync without restarting it.
  static Future<void> updateText(String text) async {
    if (!supported || !await FlutterForegroundTask.isRunningService) return;
    await FlutterForegroundTask.updateService(notificationText: text);
  }
}
