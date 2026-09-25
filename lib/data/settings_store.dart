import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/shared_preference_keys.dart';
import 'models/app_settings.dart';

/// Reads and writes [AppSettings]. Kept free of Riverpod so background
/// isolates (foreground service, WorkManager) can load settings too.
class SettingsStore {
  SettingsStore(this.prefs);

  final SharedPreferences prefs;

  static const _defaults = AppSettings();

  AppSettings load() {
    _migrateLegacy();
    T pick<T>(String key, T fallback) {
      final v = prefs.get(key);
      return v is T ? v : fallback;
    }

    final format = prefs.getString(kExportFormatKey);
    final ipv = prefs.getString(kIpVersionKey);
    return AppSettings(
      themeMode: ThemeMode.values.firstWhere(
        (m) => m.name == prefs.getString(kThemeModeKey),
        orElse: () => _defaults.themeMode,
      ),
      accent: pick(kAccentKey, _defaults.accent),
      pingCount: pick(kPingCountKey, _defaults.pingCount),
      pingIntervalMs: pick(kPingIntervalKey, _defaults.pingIntervalMs),
      pingTimeoutSec: pick(kPingTimeoutKey, _defaults.pingTimeoutSec),
      packetSize: pick(kPacketSizeKey, _defaults.packetSize),
      ipVersion: IpVersionPref.values.firstWhere((v) => v.name == ipv, orElse: () => _defaults.ipVersion),
      slowThresholdMs: pick(kSlowThresholdKey, _defaults.slowThresholdMs),
      saveAsDefault: pick(kSaveAsDefaultKey, _defaults.saveAsDefault),
      monitorIntervalSec: pick(kMonitorIntervalKey, _defaults.monitorIntervalSec),
      monitorInBackground: pick(kMonitorBackgroundKey, _defaults.monitorInBackground),
      closeToTray: pick(kCloseToTrayKey, _defaults.closeToTray),
      launchAtStartup: pick(kLaunchAtStartupKey, _defaults.launchAtStartup),
      notificationsEnabled: pick(kNotificationsKey, _defaults.notificationsEnabled),
      notificationSound: pick(kNotificationSoundKey, _defaults.notificationSound),
      retentionDays: pick(kRetentionDaysKey, _defaults.retentionDays),
      exportFormat: ExportFormat.values.firstWhere((f) => f.name == format, orElse: () => _defaults.exportFormat),
      exportFolder: prefs.getString(kExportFolderKey),
      publicIpLookups: pick(kPublicIpLookupsKey, _defaults.publicIpLookups),
      lanDeviceWatch: pick(kLanDeviceWatchKey, _defaults.lanDeviceWatch),
    );
  }

  Future<void> save(AppSettings s) async {
    await Future.wait([
      prefs.setString(kThemeModeKey, s.themeMode.name),
      prefs.setString(kAccentKey, s.accent),
      prefs.setInt(kPingCountKey, s.pingCount),
      prefs.setInt(kPingIntervalKey, s.pingIntervalMs),
      prefs.setInt(kPingTimeoutKey, s.pingTimeoutSec),
      prefs.setInt(kPacketSizeKey, s.packetSize),
      prefs.setString(kIpVersionKey, s.ipVersion.name),
      prefs.setInt(kSlowThresholdKey, s.slowThresholdMs),
      prefs.setBool(kSaveAsDefaultKey, s.saveAsDefault),
      prefs.setInt(kMonitorIntervalKey, s.monitorIntervalSec),
      prefs.setBool(kMonitorBackgroundKey, s.monitorInBackground),
      prefs.setBool(kCloseToTrayKey, s.closeToTray),
      prefs.setBool(kLaunchAtStartupKey, s.launchAtStartup),
      prefs.setBool(kNotificationsKey, s.notificationsEnabled),
      prefs.setBool(kNotificationSoundKey, s.notificationSound),
      prefs.setInt(kRetentionDaysKey, s.retentionDays),
      prefs.setString(kExportFormatKey, s.exportFormat.name),
      if (s.exportFolder != null) prefs.setString(kExportFolderKey, s.exportFolder!),
      prefs.setBool(kPublicIpLookupsKey, s.publicIpLookups),
      prefs.setBool(kLanDeviceWatchKey, s.lanDeviceWatch),
    ]);
  }

  /// Carries the old light/dark toggle over and drops the flex scheme.
  void _migrateLegacy() {
    final legacyDark = prefs.getBool(kLegacyIsDarkModeKey);
    if (legacyDark != null && !prefs.containsKey(kThemeModeKey)) {
      prefs.setString(kThemeModeKey, (legacyDark ? ThemeMode.dark : ThemeMode.light).name);
    }
    if (legacyDark != null) prefs.remove(kLegacyIsDarkModeKey);
    if (prefs.containsKey(kLegacyFlexSchemeKey)) {
      prefs.remove(kLegacyFlexSchemeKey);
    }
  }
}
