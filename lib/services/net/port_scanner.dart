import 'dart:async';
import 'dart:convert';
import 'dart:io';

enum PortState { open, closed, filtered }

class PortResult {
  const PortResult(this.port, this.state, {this.banner, this.latencyMs});
  final int port;
  final PortState state;

  /// First line the service sent (SSH, SMTP, FTP…) or an HTTP Server header.
  final String? banner;
  final int? latencyMs;

  String get service => kPortServices[port] ?? 'unknown';

  Map<String, Object?> toJson() => {'port': port, 'state': state.name, 'banner': banner, 'ms': latencyMs};
}

/// Well-known service names.
const kPortServices = <int, String>{
  20: 'ftp-data', 21: 'ftp', 22: 'ssh', 23: 'telnet', 25: 'smtp', 53: 'dns', 67: 'dhcp',
  69: 'tftp', 80: 'http', 81: 'http-alt', 88: 'kerberos', 110: 'pop3', 111: 'rpcbind',
  119: 'nntp', 123: 'ntp', 135: 'msrpc', 137: 'netbios-ns', 139: 'netbios-ssn', 143: 'imap',
  161: 'snmp', 179: 'bgp', 389: 'ldap', 443: 'https', 445: 'smb', 465: 'smtps', 500: 'isakmp',
  515: 'printer', 548: 'afp', 554: 'rtsp', 587: 'submission', 631: 'ipp', 636: 'ldaps',
  853: 'dns-over-tls', 873: 'rsync', 902: 'vmware', 993: 'imaps', 995: 'pop3s',
  1080: 'socks', 1194: 'openvpn', 1433: 'mssql', 1521: 'oracle', 1723: 'pptp', 1883: 'mqtt',
  1900: 'upnp', 2049: 'nfs', 2375: 'docker', 2376: 'docker-tls', 3000: 'dev-http',
  3128: 'squid', 3306: 'mysql', 3389: 'rdp', 3478: 'stun', 4443: 'https-alt', 5000: 'upnp/synology',
  5001: 'synology-https', 5060: 'sip', 5222: 'xmpp', 5353: 'mdns', 5432: 'postgres',
  5555: 'adb', 5900: 'vnc', 5985: 'winrm', 6379: 'redis', 6443: 'kubernetes', 6881: 'bittorrent',
  7000: 'airplay', 8000: 'http-alt', 8008: 'http-alt', 8080: 'http-proxy', 8081: 'http-alt',
  8086: 'influxdb', 8123: 'home-assistant', 8200: 'vault', 8443: 'https-alt', 8554: 'rtsp-alt',
  8883: 'mqtt-tls', 8888: 'http-alt', 9000: 'http-alt', 9090: 'prometheus', 9100: 'jetdirect',
  9200: 'elasticsearch', 9418: 'git', 10000: 'webmin', 11211: 'memcached', 25565: 'minecraft',
  27017: 'mongodb', 32400: 'plex', 49152: 'upnp', 62078: 'iphone-sync',
};

/// The COMMON preset.
const kCommonPorts = <int>[
  21, 22, 23, 25, 53, 80, 81, 88, 110, 111, 135, 139, 143, 161, 389, 443, 445, 465, 548, 554,
  587, 631, 993, 995, 1080, 1194, 1433, 1521, 1723, 1883, 1900, 2049, 2375, 3000, 3128, 3306,
  3389, 5000, 5001, 5060, 5222, 5432, 5555, 5900, 5985, 6379, 7000, 8000, 8008, 8080, 8081,
  8123, 8443, 8554, 8888, 9000, 9090, 9100, 9200, 10000, 11211, 25565, 27017, 32400, 49152, 62078,
];

/// Parses "22,80,443,8000-8100" into a sorted port list.
List<int> parsePortSpec(String spec) {
  final out = <int>{};
  for (final part in spec.split(RegExp(r'[,\s]+'))) {
    if (part.isEmpty) continue;
    final range = part.split('-');
    final a = int.tryParse(range.first);
    final b = range.length > 1 ? int.tryParse(range[1]) : a;
    if (a == null || b == null) throw FormatException('Bad port: $part');
    if (a < 1 || b > 65535 || a > b) throw FormatException('Ports must be 1–65535: $part');
    for (var p = a; p <= b; p++) {
      out.add(p);
    }
  }
  return out.toList()..sort();
}

/// TCP connect scanner. Refused → closed, timeout → filtered.
class PortScanner {
  const PortScanner({this.timeout = const Duration(milliseconds: 900), this.concurrency = 128});

  final Duration timeout;
  final int concurrency;

  /// Streams one result per port (in completion order).
  Stream<PortResult> scan(InternetAddress host, List<int> ports, {bool grabBanners = true}) {
    final controller = StreamController<PortResult>();
    var next = 0;
    var active = 0;
    var cancelled = false;

    void pump() {
      while (!cancelled && active < concurrency && next < ports.length) {
        final port = ports[next++];
        active++;
        probe(host, port, grabBanner: grabBanners).then((r) {
          active--;
          if (!cancelled) controller.add(r);
          if (next >= ports.length && active == 0) {
            controller.close();
          } else {
            pump();
          }
        });
      }
      if (ports.isEmpty) controller.close();
    }

    controller.onListen = pump;
    controller.onCancel = () => cancelled = true;
    return controller.stream;
  }

  Future<PortResult> probe(InternetAddress host, int port, {bool grabBanner = true}) async {
    final sw = Stopwatch()..start();
    Socket? socket;
    try {
      socket = await Socket.connect(host, port, timeout: timeout);
      final ms = sw.elapsedMilliseconds;
      final banner = grabBanner ? await _banner(socket, host, port) : null;
      return PortResult(port, PortState.open, banner: banner, latencyMs: ms);
    } on SocketException catch (e) {
      final code = e.osError?.errorCode;
      final msg = (e.osError?.message ?? e.message).toLowerCase();
      // ECONNREFUSED (Linux 111, macOS 61, Windows 10061) means the host
      // answered with RST: the port is closed, not filtered.
      final refused = code == 111 || code == 61 || code == 10061 || msg.contains('refused');
      return PortResult(port, refused ? PortState.closed : PortState.filtered);
    } on TimeoutException {
      return PortResult(port, PortState.filtered);
    } on Object {
      return PortResult(port, PortState.filtered);
    } finally {
      socket?.destroy();
    }
  }

  Future<String?> _banner(Socket socket, InternetAddress host, int port) async {
    final httpish = const {80, 81, 3000, 5000, 8000, 8008, 8080, 8081, 8123, 8888, 9000, 32400}.contains(port);
    try {
      if (httpish) {
        socket.write('HEAD / HTTP/1.0\r\nHost: ${host.address}\r\nUser-Agent: Pulse\r\n\r\n');
      }
      final bytes = <int>[];
      final done = Completer<void>();
      Timer? quiet;
      final hard = Timer(const Duration(milliseconds: 1500), () {
        if (!done.isCompleted) done.complete();
      });
      final sub = socket.listen(
        (d) {
          bytes.addAll(d);
          // Stop shortly after the first chunk, or once we have plenty.
          quiet?.cancel();
          quiet = Timer(const Duration(milliseconds: 150), () {
            if (!done.isCompleted) done.complete();
          });
          if (bytes.length > 2048 && !done.isCompleted) done.complete();
        },
        onError: (Object _) {
          if (!done.isCompleted) done.complete();
        },
        onDone: () {
          if (!done.isCompleted) done.complete();
        },
      );
      await done.future;
      hard.cancel();
      quiet?.cancel();
      await sub.cancel();
      if (bytes.isEmpty) return null;
      final text = utf8.decode(bytes, allowMalformed: true);
      if (httpish || text.startsWith('HTTP/')) {
        final server = RegExp(r'^server:\s*(.+)$', caseSensitive: false, multiLine: true).firstMatch(text);
        final status = text.split('\n').first.trim();
        return server == null ? status : server.group(1)!.trim();
      }
      final line = text.split('\n').first.trim().replaceAll(RegExp(r'[^\x20-\x7E]'), '');
      return line.isEmpty ? null : (line.length > 80 ? line.substring(0, 80) : line);
    } on Object {
      return null;
    }
  }
}
