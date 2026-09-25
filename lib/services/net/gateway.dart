import 'dart:io';

import 'package:network_info_plus/network_info_plus.dart';

/// Finds the IPv4 default gateway from the OS routing table.
class Gateway {
  Gateway._();

  static final _ipv4 = RegExp(r'\b((?:\d{1,3}\.){3}\d{1,3})\b');

  static Future<String?> ipv4() async {
    try {
      if (Platform.isWindows) return await _windows();
      if (Platform.isLinux) return await _linux();
      if (Platform.isMacOS) return await _macos();
      final ip = await NetworkInfo().getWifiGatewayIP();
      return ip == null || ip.isEmpty || ip == '0.0.0.0' ? null : ip;
    } on Object {
      return null;
    }
  }

  static Future<String?> _windows() async {
    // `route print` is locale-independent: the 0.0.0.0/0 row carries the gateway.
    final r = await Process.run('route', ['print', '-4', '0.0.0.0']);
    for (final line in '${r.stdout}'.split('\n')) {
      final parts = line.trim().split(RegExp(r'\s+'));
      if (parts.length >= 3 && parts[0] == '0.0.0.0' && parts[1] == '0.0.0.0') {
        final gw = parts[2];
        if (_ipv4.hasMatch(gw) && gw != '0.0.0.0') return gw;
      }
    }
    return null;
  }

  static Future<String?> _linux() async {
    final r = await Process.run('ip', ['-4', 'route', 'show', 'default']);
    final m = RegExp(r'default via ((?:\d{1,3}\.){3}\d{1,3})').firstMatch('${r.stdout}');
    if (m != null) return m.group(1);
    // Fallback: /proc/net/route stores the gateway little-endian in hex.
    final lines = await File('/proc/net/route').readAsLines();
    for (final line in lines.skip(1)) {
      final f = line.split(RegExp(r'\s+'));
      if (f.length > 2 && f[1] == '00000000') {
        final hex = int.parse(f[2], radix: 16);
        return [hex & 0xFF, (hex >> 8) & 0xFF, (hex >> 16) & 0xFF, (hex >> 24) & 0xFF].join('.');
      }
    }
    return null;
  }

  static Future<String?> _macos() async {
    final r = await Process.run('/sbin/route', ['-n', 'get', 'default']);
    final m = RegExp(r'gateway:\s*((?:\d{1,3}\.){3}\d{1,3})').firstMatch('${r.stdout}');
    return m?.group(1);
  }
}
