import 'dart:async';
import 'dart:io';

import '../dns.dart';
import '../ping_prober.dart';
import 'arp_table.dart';
import 'name_probe.dart';
import 'oui.dart';

/// A host found on the LAN.
class LanHost {
  const LanHost({
    required this.ip,
    this.mac,
    this.hostname,
    this.vendor,
    this.rttMs,
    this.isGateway = false,
    this.isSelf = false,
    this.viaArpOnly = false,
  });

  final String ip;
  final String? mac;
  final String? hostname;
  final String? vendor;
  final double? rttMs;
  final bool isGateway;
  final bool isSelf;

  /// Answered ARP but not ICMP/TCP (firewalled phones, IoT).
  final bool viaArpOnly;

  int get lastOctet => int.tryParse(ip.split('.').last) ?? 0;

  LanHost copyWith({String? mac, String? hostname, String? vendor, double? rttMs}) => LanHost(
    ip: ip,
    mac: mac ?? this.mac,
    hostname: hostname ?? this.hostname,
    vendor: vendor ?? this.vendor,
    rttMs: rttMs ?? this.rttMs,
    isGateway: isGateway,
    isSelf: isSelf,
    viaArpOnly: viaArpOnly,
  );
}

enum DeviceType { router, pc, phone, tablet, tv, printer, storage, iot, camera, console, audio, unknown }

extension DeviceTypeLabel on DeviceType {
  String get label => switch (this) {
    DeviceType.router => 'ROUTER',
    DeviceType.pc => 'PC',
    DeviceType.phone => 'PHONE',
    DeviceType.tablet => 'TABLET',
    DeviceType.tv => 'TV',
    DeviceType.printer => 'PRINTER',
    DeviceType.storage => 'STORAGE',
    DeviceType.iot => 'IOT',
    DeviceType.camera => 'CAMERA',
    DeviceType.console => 'CONSOLE',
    DeviceType.audio => 'AUDIO',
    DeviceType.unknown => '?',
  };
}

/// Best guess from role, name, vendor and (when known) open ports.
DeviceType classifyDevice(LanHost h, {List<int> openPorts = const []}) {
  if (h.isGateway) return DeviceType.router;
  final name = (h.hostname ?? '').toLowerCase();
  final vendor = (h.vendor ?? '').toLowerCase();
  bool n(List<String> k) => k.any(name.contains);
  bool v(List<String> k) => k.any(vendor.contains);

  if (openPorts.contains(9100) ||
      openPorts.contains(631) ||
      n(['printer', 'laserjet', 'officejet', 'deskjet', 'epson', 'brother', 'canon', 'mfc-', 'ipp'])) {
    return DeviceType.printer;
  }
  if (n(['ipad', 'tab', 'tablet', 'kindle']) || v(['amazon technologies']) && n(['kindle'])) return DeviceType.tablet;
  if (n([
    'iphone',
    'android',
    'galaxy',
    'pixel',
    'redmi',
    'realme',
    'oneplus',
    'oppo',
    'vivo',
    'xiaomi',
    'huawei',
    'phone',
    'mi-',
  ])) {
    return DeviceType.phone;
  }
  if (n(['tv', 'bravia', 'roku', 'chromecast', 'firetv', 'fire-tv', 'shield', 'appletv', 'apple-tv', 'webos'])) {
    return DeviceType.tv;
  }
  if (n(['nas', 'diskstation', 'ds2', 'ds9', 'qnap', 'truenas', 'unraid', 'mycloud']) ||
      v(['synology', 'qnap', 'western digital', 'buffalo'])) {
    return DeviceType.storage;
  }
  if (n(['cam', 'ipc', 'nvr', 'dvr']) ||
      v(['hikvision', 'dahua', 'reolink', 'axis comm', 'wyze', 'ezviz', 'amcrest'])) {
    return DeviceType.camera;
  }
  if (n(['playstation', 'ps4', 'ps5', 'xbox', 'switch', 'nintendo']) ||
      v(['sony interactive', 'nintendo', 'microsoft']) && n(['xbox'])) {
    return DeviceType.console;
  }
  if (n(['sonos', 'echo', 'homepod', 'speaker', 'soundbar']) || v(['sonos', 'bose', 'harman'])) return DeviceType.audio;
  if (v([
    'espressif',
    'tuya',
    'shelly',
    'sonoff',
    'itead',
    'lifi',
    'signify',
    'philips lighting',
    'tp-link smart',
    'wiz',
    'broadlink',
    'xiaomi communications',
    'beijing xiaomi',
    'raspberry',
    'arduino',
    'particle',
    'nordic',
  ])) {
    return DeviceType.iot;
  }
  if (v(['apple']) && n(['macbook', 'imac', 'mac-', 'mac.'])) return DeviceType.pc;
  if (v(['apple'])) return DeviceType.phone;
  if (v([
    'samsung',
    'xiaomi',
    'oneplus',
    'oppo',
    'vivo',
    'realme',
    'huawei',
    'honor',
    'motorola',
    'google',
    'nothing tech',
    'zte',
    'lg electronics',
  ])) {
    return name.isEmpty ? DeviceType.phone : DeviceType.phone;
  }
  if (h.isSelf ||
      openPorts.contains(3389) ||
      openPorts.contains(445) ||
      openPorts.contains(139) ||
      n(['pc', 'desktop', 'laptop', 'workstation', 'win-', 'macbook', 'thinkpad']) ||
      v([
        'intel',
        'dell',
        'lenovo',
        'hewlett',
        'asustek',
        'micro-star',
        'gigabyte',
        'realtek',
        'liteon',
        'azurewave',
        'hon hai',
        'foxconn',
        'acer',
      ])) {
    return DeviceType.pc;
  }
  if (v([
    'tp-link',
    'netgear',
    'ubiquiti',
    'mikrotik',
    'cisco',
    'zyxel',
    'd-link',
    'huawei tech',
    'tenda',
    'arris',
    'technicolor',
    'sagemcom',
  ])) {
    return DeviceType.router;
  }
  return DeviceType.unknown;
}

/// Progress of a running sweep.
class LanScanProgress {
  const LanScanProgress({
    required this.probed,
    required this.total,
    required this.hosts,
    this.current,
    this.phase = 'probing',
  });

  final int probed;
  final int total;
  final List<LanHost> hosts;
  final String? current;

  /// probing | arp | names | done
  final String phase;
}

/// Sweeps an IPv4 subnet: ICMP echo to every host (which also fills the
/// ARP cache), then the ARP table, then names (PTR, NetBIOS, mDNS) and
/// vendors (OUI) for everything that answered.
class LanScanner {
  LanScanner({this.prober = const PingProber(), this.concurrency = 48});

  final PingProber prober;
  final int concurrency;

  /// Hosts in the subnet of [ip]/[prefix], capped to the /22 around us.
  static List<String> hostsFor(String ip, int prefix) {
    final p = prefix.clamp(22, 30);
    final parts = ip.split('.').map(int.parse).toList();
    final addr = (parts[0] << 24) | (parts[1] << 16) | (parts[2] << 8) | parts[3];
    final mask = (0xFFFFFFFF << (32 - p)) & 0xFFFFFFFF;
    final net = addr & mask;
    final bcast = net | (~mask & 0xFFFFFFFF);
    return [for (var a = net + 1; a < bcast; a++) '${(a >> 24) & 255}.${(a >> 16) & 255}.${(a >> 8) & 255}.${a & 255}'];
  }

  static String cidrFor(String ip, int prefix) {
    final p = prefix.clamp(22, 30);
    final hosts = hostsFor(ip, p);
    final first = hosts.first.split('.').map(int.parse).toList();
    first[3] -= 1;
    return '${first.join('.')}/$p';
  }

  static String broadcastFor(String ip, int prefix) {
    final hosts = hostsFor(ip, prefix);
    final last = hosts.last.split('.').map(int.parse).toList();
    last[3] += 1;
    return last.join('.');
  }

  Stream<LanScanProgress> scan({required String localIp, required int prefix, String? gateway}) async* {
    final targets = hostsFor(localIp, prefix);
    final found = <String, LanHost>{};
    var probed = 0;
    String? current;

    final queue = List.of(targets);
    final updates = StreamController<void>();
    var active = 0;

    // TCP ports that make firewalled phones and PCs answer when ICMP is dropped.
    const tcpFallback = [80, 443, 22, 445, 62078, 8080, 7000, 5353];
    final mobile = Platform.isAndroid || Platform.isIOS;

    Future<void> probeOne(String ip) async {
      current = ip;
      final r = await prober.probe(ip, timeout: const Duration(milliseconds: 900), packetSize: 32);
      double? rtt = r.ok ? r.rttMs : null;
      if (rtt == null && mobile) {
        // No ARP table on phones: try a few TCP ports instead.
        for (final port in tcpFallback) {
          final sw = Stopwatch()..start();
          try {
            final s = await Socket.connect(ip, port, timeout: const Duration(milliseconds: 250));
            s.destroy();
            rtt = sw.elapsedMicroseconds / 1000;
            break;
          } on SocketException catch (e) {
            // A refusal still proves the host is up.
            if ((e.osError?.message ?? '').toLowerCase().contains('refused')) {
              rtt = sw.elapsedMicroseconds / 1000;
              break;
            }
          } on Object {
            // Try the next port.
          }
        }
      }
      if (rtt != null) {
        found[ip] = LanHost(ip: ip, rttMs: rtt, isGateway: ip == gateway, isSelf: ip == localIp);
      }
      probed++;
      updates.add(null);
    }

    void pump() {
      while (active < concurrency && queue.isNotEmpty) {
        final ip = queue.removeAt(0);
        active++;
        probeOne(ip).whenComplete(() {
          active--;
          if (queue.isEmpty && active == 0) {
            updates.close();
          } else {
            pump();
          }
        });
      }
    }

    found[localIp] = LanHost(ip: localIp, rttMs: 0, isSelf: true, isGateway: localIp == gateway);
    pump();
    var lastEmit = DateTime.fromMillisecondsSinceEpoch(0);
    await for (final _ in updates.stream) {
      final now = DateTime.now();
      if (now.difference(lastEmit).inMilliseconds > 120) {
        lastEmit = now;
        yield LanScanProgress(probed: probed, total: targets.length, hosts: _sorted(found), current: current);
      }
    }

    yield LanScanProgress(probed: probed, total: targets.length, hosts: _sorted(found), phase: 'arp');
    final arp = await ArpTable.read();
    final targetSet = targets.toSet();
    for (final e in arp.entries) {
      if (!targetSet.contains(e.key)) continue;
      final h = found[e.key];
      found[e.key] = h == null
          ? LanHost(ip: e.key, mac: e.value, isGateway: e.key == gateway, viaArpOnly: true)
          : h.copyWith(mac: e.value);
    }
    if (!found.containsKey(localIp)) {
      found[localIp] = LanHost(ip: localIp, rttMs: 0, isSelf: true);
    }
    // This machine's own MAC is not in its ARP table.
    final selfMac = await _selfMac(localIp);
    if (selfMac != null) found[localIp] = found[localIp]!.copyWith(mac: selfMac);

    yield LanScanProgress(probed: probed, total: targets.length, hosts: _sorted(found), phase: 'names');
    final oui = await OuiDb.load();
    await Future.wait([
      for (final h in found.values.toList())
        _name(h).then((name) {
          found[h.ip] = found[h.ip]!.copyWith(hostname: name, vendor: oui.vendor(h.mac));
        }),
    ]);
    yield LanScanProgress(probed: probed, total: targets.length, hosts: _sorted(found), phase: 'done');
  }

  Future<String?> _name(LanHost h) async {
    if (h.isSelf) return Platform.localHostname;
    final results = await Future.wait([Dns.reverse(h.ip), NameProbe.netbios(h.ip), NameProbe.mdns(h.ip)]);
    String? clean(String? n) {
      if (n == null || n.isEmpty) return null;
      final s = n.replaceAll(RegExp(r'\.(local|lan|home|localdomain|domain|router)\.?$'), '');
      return s == h.ip ? null : s;
    }

    // Prefer self-reported names over router DNS guesses.
    return clean(results[2]) ?? clean(results[1]) ?? clean(results[0]);
  }

  Future<String?> _selfMac(String ip) async {
    try {
      if (Platform.isWindows) {
        final out = '${(await Process.run('getmac', ['/v', '/fo', 'csv', '/nh'])).stdout}';
        final ipconfig = '${(await Process.run('ipconfig', ['/all'])).stdout}';
        // Find the adapter block that owns [ip] and read its physical address.
        final blocks = ipconfig.split(RegExp(r'\r?\n(?=\S)'));
        for (final b in blocks) {
          if (b.contains(ip)) {
            final m = RegExp(r'([0-9A-F]{2}-){5}[0-9A-F]{2}').firstMatch(b);
            if (m != null) return m.group(0)!.replaceAll('-', ':');
          }
        }
        return RegExp(r'([0-9A-F]{2}-){5}[0-9A-F]{2}').firstMatch(out)?.group(0)?.replaceAll('-', ':');
      }
      if (Platform.isLinux || Platform.isMacOS) {
        for (final iface in await NetworkInterface.list()) {
          if (iface.addresses.any((a) => a.address == ip)) {
            if (Platform.isLinux) {
              return (await File('/sys/class/net/${iface.name}/address').readAsString()).trim().toUpperCase();
            }
            final ifc = '${(await Process.run('/sbin/ifconfig', [iface.name])).stdout}';
            return RegExp(r'ether ([0-9a-f:]{17})').firstMatch(ifc)?.group(1)?.toUpperCase();
          }
        }
      }
    } on Object {
      return null;
    }
    return null;
  }

  static List<LanHost> _sorted(Map<String, LanHost> m) =>
      m.values.toList()..sort((a, b) => a.lastOctet.compareTo(b.lastOctet));
}
