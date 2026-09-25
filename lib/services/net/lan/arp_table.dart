import 'dart:io';

/// IP → MAC pairs from the OS neighbour cache.
///
/// Android 10+ and iOS do not expose the neighbour table to apps, so this
/// returns an empty map there (vendors then show as unknown).
class ArpTable {
  ArpTable._();

  static final _ipv4 = RegExp(r'((?:\d{1,3}\.){3}\d{1,3})');
  static final _mac = RegExp(r'([0-9A-Fa-f]{1,2}[:-]){5}[0-9A-Fa-f]{1,2}');

  static bool get available => Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  static Future<Map<String, String>> read() async {
    try {
      if (Platform.isWindows) return parse('${(await Process.run('arp', ['-a'])).stdout}');
      if (Platform.isMacOS) return parse('${(await Process.run('/usr/sbin/arp', ['-an'])).stdout}');
      if (Platform.isLinux) {
        final neigh = await Process.run('ip', ['-4', 'neigh']);
        final fromIp = parse('${neigh.stdout}');
        if (fromIp.isNotEmpty) return fromIp;
        return parse(await File('/proc/net/arp').readAsString());
      }
    } on Object {
      // Tool missing or not permitted.
    }
    return const {};
  }

  /// Parses any of `arp -a` (Windows/macOS), `ip neigh` or /proc/net/arp.
  static Map<String, String> parse(String output) {
    final out = <String, String>{};
    for (final line in output.split('\n')) {
      final ip = _ipv4.firstMatch(line)?.group(1);
      final mac = _mac.firstMatch(line)?.group(0);
      if (ip == null || mac == null) continue;
      final norm = mac.split(RegExp('[:-]')).map((p) => p.padLeft(2, '0').toUpperCase()).join(':');
      if (norm == 'FF:FF:FF:FF:FF:FF' || norm == '00:00:00:00:00:00') continue;
      if (norm.startsWith('01:00:5E')) continue; // IPv4 multicast
      out[ip] = norm;
    }
    return out;
  }
}
