import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

/// Starts Pulse when the user logs in (desktop only). Launched this way the
/// app gets `--autostart` and opens straight into the tray.
class LaunchAtLogin {
  LaunchAtLogin._();

  static const flag = '--autostart';
  static const _runKey = r'HKCU\Software\Microsoft\Windows\CurrentVersion\Run';
  static const _channel = MethodChannel('pulse/launch_at_login');

  static bool get supported => Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  static Future<bool> isEnabled() async {
    if (Platform.isWindows) {
      final r = await Process.run('reg', ['query', _runKey, '/v', 'Pulse']);
      return r.exitCode == 0;
    }
    if (Platform.isMacOS) return await _channel.invokeMethod<bool>('isEnabled') ?? false;
    if (Platform.isLinux) return File(_desktopFile).existsSync();
    return false;
  }

  static Future<void> setEnabled(bool on) async {
    if (Platform.isWindows) {
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
    final config = Platform.environment['XDG_CONFIG_HOME'] ??
        p.join(Platform.environment['HOME'] ?? '', '.config');
    return p.join(config, 'autostart', 'pulse.desktop');
  }
}
