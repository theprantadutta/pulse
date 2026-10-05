import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

/// Windows refused to enable the startup task (turned off by the user in
/// Task Manager, or by policy). Only the user can turn it back on there.
class LaunchAtLoginBlocked implements Exception {
  LaunchAtLoginBlocked(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Starts Pulse when the user logs in (desktop only). Launched this way the
/// app gets `--autostart` and opens straight into the tray.
///
/// - Windows MSIX build: the package's StartupTask (pubspec `msix_config`
///   `startup_task`), driven through the runner's C++/WinRT channel.
/// - Windows unpackaged build: the HKCU Run key.
/// - macOS: SMAppService. Linux: an XDG autostart entry.
class LaunchAtLogin {
  LaunchAtLogin._();

  static const flag = '--autostart';
  static const _runKey = r'HKCU\Software\Microsoft\Windows\CurrentVersion\Run';
  static const _channel = MethodChannel('pulse/launch_at_login');

  // Windows.ApplicationModel.StartupTaskState
  static const _disabledByUser = 1;
  static const _enabled = 2;
  static const _disabledByPolicy = 3;
  static const _enabledByPolicy = 4;

  static bool get supported => Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  static bool? _packaged;

  /// True for the MSIX (Microsoft Store) build on Windows.
  static Future<bool> get isPackaged async {
    if (!Platform.isWindows) return false;
    return _packaged ??= await _channel.invokeMethod<bool>('isPackaged') ?? false;
  }

  /// The OS owns the switch (the user can change it outside Pulse), so the
  /// app should read it rather than force its own setting.
  static Future<bool> get isManagedBySystem async => Platform.isMacOS || await isPackaged;

  static Future<bool> isEnabled() async {
    if (Platform.isWindows) {
      if (await isPackaged) {
        final state = await _channel.invokeMethod<int>('getState');
        return state == _enabled || state == _enabledByPolicy;
      }
      final r = await Process.run('reg', ['query', _runKey, '/v', 'Pulse']);
      return r.exitCode == 0;
    }
    if (Platform.isMacOS) return await _channel.invokeMethod<bool>('isEnabled') ?? false;
    if (Platform.isLinux) return File(_desktopFile).existsSync();
    return false;
  }

  static Future<void> setEnabled(bool on) async {
    if (Platform.isWindows) {
      if (await isPackaged) {
        final state = await _channel.invokeMethod<int>('setEnabled', {'enabled': on});
        if (on && state == _disabledByUser) {
          throw LaunchAtLoginBlocked('Startup is turned off for Pulse in Task Manager › Startup apps. Turn it on there.');
        }
        if (on && state == _disabledByPolicy) {
          throw LaunchAtLoginBlocked('Your organisation has turned off startup apps for Pulse.');
        }
        return;
      }
      if (on) {
        final exe = Platform.resolvedExecutable;
        final r = await Process.run('reg', ['add', _runKey, '/v', 'Pulse', '/t', 'REG_SZ', '/d', '"$exe" $flag', '/f']);
        if (r.exitCode != 0) throw ProcessException('reg', const [], '${r.stderr}', r.exitCode);
      } else {
        await Process.run('reg', ['delete', _runKey, '/v', 'Pulse', '/f']);
      }
      return;
    }
    if (Platform.isMacOS) {
      await _channel.invokeMethod<void>('setEnabled', {'enabled': on});
      return;
    }
    if (Platform.isLinux) {
      final f = File(_desktopFile);
      if (on) {
        await f.parent.create(recursive: true);
        await f.writeAsString(
          '[Desktop Entry]\n'
          'Type=Application\n'
          'Name=Pulse\n'
          'Comment=Network diagnostics and monitoring\n'
          'Exec="${Platform.resolvedExecutable}" $flag\n'
          'X-GNOME-Autostart-enabled=true\n'
          'Terminal=false\n',
        );
      } else if (f.existsSync()) {
        await f.delete();
      }
    }
  }

  static String get _desktopFile {
    final config = Platform.environment['XDG_CONFIG_HOME'] ?? p.join(Platform.environment['HOME'] ?? '', '.config');
    return p.join(config, 'autostart', 'pulse.desktop');
  }
}
