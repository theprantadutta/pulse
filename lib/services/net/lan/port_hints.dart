import 'dart:async';
import 'dart:io';

/// A TCP port that, when open, says what kind of device answers on it.
class PortHint {
  const PortHint(this.port, this.label, this.kind);
  final int port;

  /// "iPhone or iPad", "Google Cast", "Printer"…
  final String label;

  /// Device kind this port points to (matches DeviceType names).
  final String kind;
}

/// Quick identification by open ports: one short connect per hint port.
class PortHints {
  PortHints._();

  static const hints = <PortHint>[
    PortHint(62078, 'iPhone or iPad', 'phone'),
    PortHint(8009, 'Google Cast', 'tv'),
    PortHint(8060, 'Roku', 'tv'),
    PortHint(5555, 'Android TV (ADB)', 'tv'),
    PortHint(7000, 'AirPlay', 'tv'),
    PortHint(9100, 'Printer', 'printer'),
    PortHint(631, 'Printer (IPP)', 'printer'),
    PortHint(515, 'Printer (LPD)', 'printer'),
    PortHint(554, 'Camera stream (RTSP)', 'camera'),
    PortHint(3389, 'Windows Remote Desktop', 'pc'),
    PortHint(445, 'File sharing (SMB)', 'pc'),
    PortHint(5000, 'Synology / NAS', 'storage'),
    PortHint(1400, 'Sonos', 'audio'),
    PortHint(9295, 'PlayStation Remote Play', 'console'),
    PortHint(32400, 'Plex', 'storage'),
    PortHint(1883, 'Smart-home hub (MQTT)', 'iot'),
  ];

  /// IP → the hint ports that accepted a connection. Runs [concurrency]
  /// connects at a time with a short timeout, so a few seconds at most.
  static Future<Map<String, List<int>>> probe(
    List<String> ips, {
    Duration timeout = const Duration(milliseconds: 450),
    int concurrency = 64,
  }) async {
    final jobs = [
      for (final ip in ips)
        for (final h in hints) (ip, h.port),
    ];
    final open = <String, List<int>>{};
    var next = 0;
    Future<void> worker() async {
      while (next < jobs.length) {
        final (ip, port) = jobs[next++];
        try {
          final s = await Socket.connect(ip, port, timeout: timeout);
          s.destroy();
          (open[ip] ??= []).add(port);
        } on Object {
          // Closed or filtered.
        }
      }
    }

    await Future.wait([for (var i = 0; i < concurrency; i++) worker()]);
    for (final l in open.values) {
      l.sort();
    }
    return open;
  }

  static PortHint? hintFor(int port) {
    for (final h in hints) {
      if (h.port == port) return h;
    }
    return null;
  }
}
