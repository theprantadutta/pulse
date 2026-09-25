import 'package:material_ui/material_ui.dart';

/// IP family selection for ping-style tools.
enum IpVersionPref { auto, ipv4, ipv6, both }

enum ExportFormat { csv, txt }

/// Every user-tunable value, persisted in SharedPreferences.
@immutable
class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.accent = 'ORANGE',
    this.pingCount = 0,
    this.pingIntervalMs = 1000,
    this.pingTimeoutSec = 5,
    this.packetSize = 56,
    this.ipVersion = IpVersionPref.auto,
    this.slowThresholdMs = 60,
    this.saveAsDefault = true,
    this.monitorIntervalSec = 60,
    this.monitorInBackground = true,
    this.closeToTray = true,
    this.launchAtStartup = false,
    this.notificationsEnabled = true,
    this.notificationSound = true,
    this.retentionDays = 90,
    this.exportFormat = ExportFormat.csv,
    this.exportFolder,
    this.publicIpLookups = true,
    this.lanDeviceWatch = false,
  });

  final ThemeMode themeMode;
  final String accent;

  /// 0 means continuous (∞).
  final int pingCount;
  final int pingIntervalMs;
  final int pingTimeoutSec;
  final int packetSize;
  final IpVersionPref ipVersion;
  final int slowThresholdMs;
  final bool saveAsDefault;

  final int monitorIntervalSec;
  final bool monitorInBackground;
  final bool closeToTray;
  final bool launchAtStartup;

  final bool notificationsEnabled;
  final bool notificationSound;

  final int retentionDays;
  final ExportFormat exportFormat;
  final String? exportFolder;

  /// Allows sending IPs to ip-api.com / ipinfo.io for ISP and geo lookups.
  final bool publicIpLookups;

  /// Periodically sweeps the LAN in the background to detect new devices.
  final bool lanDeviceWatch;

  AppSettings copyWith({
    ThemeMode? themeMode,
    String? accent,
    int? pingCount,
    int? pingIntervalMs,
    int? pingTimeoutSec,
    int? packetSize,
    IpVersionPref? ipVersion,
    int? slowThresholdMs,
    bool? saveAsDefault,
    int? monitorIntervalSec,
    bool? monitorInBackground,
    bool? closeToTray,
    bool? launchAtStartup,
    bool? notificationsEnabled,
    bool? notificationSound,
    int? retentionDays,
    ExportFormat? exportFormat,
    String? exportFolder,
    bool? publicIpLookups,
    bool? lanDeviceWatch,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      accent: accent ?? this.accent,
      pingCount: pingCount ?? this.pingCount,
      pingIntervalMs: pingIntervalMs ?? this.pingIntervalMs,
      pingTimeoutSec: pingTimeoutSec ?? this.pingTimeoutSec,
      packetSize: packetSize ?? this.packetSize,
      ipVersion: ipVersion ?? this.ipVersion,
      slowThresholdMs: slowThresholdMs ?? this.slowThresholdMs,
      saveAsDefault: saveAsDefault ?? this.saveAsDefault,
      monitorIntervalSec: monitorIntervalSec ?? this.monitorIntervalSec,
      monitorInBackground: monitorInBackground ?? this.monitorInBackground,
      closeToTray: closeToTray ?? this.closeToTray,
      launchAtStartup: launchAtStartup ?? this.launchAtStartup,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      notificationSound: notificationSound ?? this.notificationSound,
      retentionDays: retentionDays ?? this.retentionDays,
      exportFormat: exportFormat ?? this.exportFormat,
      exportFolder: exportFolder ?? this.exportFolder,
      publicIpLookups: publicIpLookups ?? this.publicIpLookups,
      lanDeviceWatch: lanDeviceWatch ?? this.lanDeviceWatch,
    );
  }
}
