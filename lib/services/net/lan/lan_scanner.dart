import 'dart:async';
import 'dart:io';
import 'dart:ui' show PlatformDispatcher;

import '../dns.dart';
import '../ping_prober.dart';
import 'arp_table.dart';
import 'mdns_browser.dart';
import 'name_probe.dart';
import 'oui.dart';
import 'port_hints.dart';
import 'router_names.dart';
import 'ssdp.dart';

/// Whether the device running Pulse is a tablet: shortest side ≥ 600 dp, the
/// same split the shell and main.dart use.
bool get thisDeviceIsTablet {
  final views = PlatformDispatcher.instance.views;
  if (views.isEmpty) return false;
  final v = views.first;
  return v.physicalSize.shortestSide / v.devicePixelRatio >= 600;
}

/// A host found on the LAN, and everything Pulse learned about it.
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
    this.friendlyName,
    this.model,
    this.deviceKind,
    this.services = const [],
    this.hintPorts = const [],
    this.sources = const [],
    this.identity,
  });

  final String ip;
  final String? mac;

  /// Network name: the device's own mDNS / NetBIOS name, or the one the
  /// router's DNS gave it ("Galaxy-A24", "DESKTOP-4F2K").
  final String? hostname;
  final String? vendor;
  final double? rttMs;
  final bool isGateway;
  final bool isSelf;

  /// Answered ARP but not ICMP/TCP (firewalled phones, IoT).
  final bool viaArpOnly;

  /// The name the device announces for people ("Living Room TV"), from UPnP
  /// or mDNS.
  final String? friendlyName;

  /// Maker and model ("Samsung QE55Q60", "Chromecast", "MacBook Pro").
  final String? model;

  /// UPnP device type ("MediaRenderer", "InternetGatewayDevice").
  final String? deviceKind;

  /// What it offers ("Google Cast", "AirPlay", "Printer").
  final List<String> services;

  /// Identifying ports that accepted a connection (PortHints).
  final List<int> hintPorts;

  /// How Pulse found and named it ("Ping", "mDNS", "UPnP", "Router DNS"…).
  final List<String> sources;

  /// Something stable across IP changes (UPnP UDN, mDNS name, hostname),
  /// used to keep a custom name when the router hands out a new address.
  final String? identity;

  int get lastOctet => int.tryParse(ip.split('.').last) ?? 0;

  LanHost copyWith({
    String? mac,
    String? hostname,
    String? vendor,
    double? rttMs,
    String? friendlyName,
    String? model,
    String? deviceKind,
    List<String>? services,
    List<int>? hintPorts,
    List<String>? sources,
    String? identity,
  }) => LanHost(
    ip: ip,
    mac: mac ?? this.mac,
    hostname: hostname ?? this.hostname,
    vendor: vendor ?? this.vendor,
    rttMs: rttMs ?? this.rttMs,
    isGateway: isGateway,
    isSelf: isSelf,
    viaArpOnly: viaArpOnly,
    friendlyName: friendlyName ?? this.friendlyName,
    model: model ?? this.model,
    deviceKind: deviceKind ?? this.deviceKind,
    services: services ?? this.services,
    hintPorts: hintPorts ?? this.hintPorts,
    sources: sources ?? this.sources,
    identity: identity ?? this.identity,
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

/// Best guess at what a device is. What it says about itself (UPnP device
/// type, mDNS services, model, identifying ports) comes before guesses from
/// its name and network-card vendor.
DeviceType classifyDevice(LanHost h, {List<int> openPorts = const []}) {
  if (h.isGateway) return DeviceType.router;
  final ports = {...openPorts, ...h.hintPorts};
  final name = [h.hostname, h.friendlyName, h.model].whereType<String>().join(' ').toLowerCase();
  final model = (h.model ?? '').toLowerCase();
  final vendor = (h.vendor ?? '').toLowerCase();
  final kind = (h.deviceKind ?? '').toLowerCase();
  final svc = h.services.toSet();
  bool n(List<String> k) => k.any(name.contains);
  bool v(List<String> k) => k.any(vendor.contains);
  bool s(List<String> k) => k.any(svc.contains);
  bool p(List<int> k) => k.any(ports.contains);
  final windows = p([3389]) || s(['Remote desktop']);

  // Access points and mesh nodes describe themselves as gateways.
  if (kind.contains('internetgateway') || kind.contains('wfadevice') || kind.contains('wlanaccesspoint')) {
    return DeviceType.router;
  }
  if (s(['Printer', 'Scanner']) ||
      kind.contains('printer') ||
      p([9100, 631, 515]) ||
      n(['printer', 'laserjet', 'officejet', 'deskjet', 'epson', 'brother', 'canon', 'mfc-', 'ipp'])) {
    return DeviceType.printer;
  }
  // Apple model ids from mDNS ("iPhone15,2", "MacBookPro18,1", "AppleTV11,1").
  if (model.startsWith('iphone')) return DeviceType.phone;
  if (model.startsWith('ipad')) return DeviceType.tablet;
  if (model.startsWith('appletv') || model.startsWith('apple tv')) return DeviceType.tv;
  if (model.startsWith('audioaccessory') || model.contains('homepod')) return DeviceType.audio;
  if (RegExp(r'^(mac|imac|macbook|mac mini|mac pro|mac studio)').hasMatch(model)) return DeviceType.pc;
  if (n(['homepod', 'nest audio', 'nest mini', 'home mini', 'google home', 'echo', 'sonos', 'soundbar', 'speaker']) ||
      s(['Sonos']) ||
      p([1400]) ||
      v(['sonos', 'bose', 'harman'])) {
    return DeviceType.audio;
  }
  if (p([9295]) || n(['playstation', 'ps4', 'ps5', 'xbox', 'nintendo']) || v(['sony interactive', 'nintendo'])) {
    return DeviceType.console;
  }
  if (s(['Google Cast', 'Fire TV', 'Android TV']) ||
      p([8009, 8060, 5555]) ||
      (kind.contains('mediarenderer') && !windows && !p([445])) ||
      n([
        'tv',
        'bravia',
        'roku',
        'chromecast',
        'firetv',
        'fire-tv',
        'shield',
        'appletv',
        'apple-tv',
        'webos',
        'tizen',
      ])) {
    return DeviceType.tv;
  }
  if (p([554]) ||
      kind.contains('camera') ||
      n(['cam', 'ipc', 'nvr', 'dvr']) ||
      v(['hikvision', 'dahua', 'reolink', 'axis comm', 'wyze', 'ezviz', 'amcrest'])) {
    return DeviceType.camera;
  }
  if (p([5000, 32400]) ||
      s(['Plex']) ||
      n(['nas', 'diskstation', 'ds2', 'ds9', 'qnap', 'truenas', 'unraid', 'mycloud']) ||
      v(['synology', 'qnap', 'western digital', 'buffalo'])) {
    return DeviceType.storage;
  }
  if (s(['HomeKit', 'Matter', 'Philips Hue', 'ESPHome', 'Xiaomi', 'MQTT', 'Elgato', 'Home Assistant']) ||
      p([1883]) ||
      v([
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
  if (n(['ipad', 'tab', 'tablet', 'kindle'])) return DeviceType.tablet;
  if (p([62078]) ||
      n([
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
  if (h.isSelf && (Platform.isAndroid || Platform.isIOS)) {
    return thisDeviceIsTablet ? DeviceType.tablet : DeviceType.phone;
  }
  if (h.isSelf ||
      windows ||
      s(['Computer', 'Screen sharing']) ||
      p([445, 139]) ||
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
  if (v(['apple']) || s(['Apple device'])) return DeviceType.phone;
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
    return DeviceType.phone;
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
/// ARP cache), then the ARP table, then identifies everything: the router's
/// DNS names, UPnP descriptions, mDNS services, NetBIOS, identifying ports and
/// vendors (OUI). Each source is optional: routers differ, and whatever one
/// doesn't answer, the others still fill in.
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

  /// [dnsServers] are the network's DNS servers (the router is asked too).
  Stream<LanScanProgress> scan({
    required String localIp,
    required int prefix,
    String? gateway,
    List<String> dnsServers = const [],
  }) async* {
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
    final others = [
      for (final ip in found.keys)
        if (ip != localIp) ip,
    ];
    bool inSubnet(String ip) => targetSet.contains(ip) && ip != localIp;
    final (oui, routerNames, upnp, mdns, hints, probes) = await (
      OuiDb.load(),
      RouterNames.lookup(others, servers: [?gateway, ...dnsServers]),
      Ssdp.discover(inSubnet: inSubnet, unicast: others),
      MdnsBrowser.browse(inSubnet: inSubnet, unicast: others),
      PortHints.probe(others),
      _probeNames(others),
    ).wait;

    // Devices that ignore ping but announce themselves still belong here.
    for (final ip in {...upnp.keys, ...mdns.keys}) {
      found.putIfAbsent(ip, () => LanHost(ip: ip, isGateway: ip == gateway));
    }
    for (final ip in found.keys.toList()) {
      found[ip] = identify(
        found[ip]!,
        oui: oui,
        routerName: routerNames[ip],
        upnp: upnp[ip],
        mdns: mdns[ip],
        hintPorts: hints[ip] ?? const [],
        probe: probes[ip],
      );
    }
    yield LanScanProgress(probed: probed, total: targets.length, hosts: _sorted(found), phase: 'done');
  }

  /// Self-reported names from each host: unicast mDNS, NetBIOS and the
  /// system resolver.
  Future<Map<String, ({String? mdns, String? netbios, String? dns})>> _probeNames(List<String> ips) async {
    final out = <String, ({String? mdns, String? netbios, String? dns})>{};
    await Future.wait([
      for (final ip in ips)
        Future.wait([NameProbe.mdns(ip), NameProbe.netbios(ip), Dns.reverse(ip)]).then((r) {
          out[ip] = (mdns: r[0], netbios: r[1], dns: r[2]);
        }),
    ]);
    return out;
  }

  /// Merges everything learned about one host. Exposed for tests.
  static LanHost identify(
    LanHost h, {
    OuiDb? oui,
    String? routerName,
    UpnpInfo? upnp,
    MdnsInfo? mdns,
    List<int> hintPorts = const [],
    ({String? mdns, String? netbios, String? dns})? probe,
  }) {
    String? clean(String? n) {
      if (n == null || n.isEmpty) return null;
      final s = n.replaceAll(RegExp(r'\.(local|lan|home|localdomain|domain|router|internal|home\.arpa)\.?$'), '');
      return s.isEmpty || s == h.ip ? null : s;
    }

    String? hostname;
    if (h.isSelf) {
      // Android/iOS report "localhost"; keep the "This device" label instead.
      final local = Platform.localHostname;
      hostname = local.isEmpty || local.toLowerCase().startsWith('localhost') ? null : local;
    } else {
      // Names a device gives itself beat the router's DHCP list, which beats
      // the system resolver (often a public DNS that knows nothing local).
      hostname = clean(probe?.mdns) ?? clean(mdns?.host) ?? clean(probe?.netbios) ?? routerName ?? clean(probe?.dns);
    }
    final mac = h.mac ?? mdns?.mac;
    final friendly = cleanFriendlyName(upnp?.friendlyName) ?? mdns?.name;
    final model = upnp?.model ?? prettyModel(mdns?.model);
    final services = <String>{...?mdns?.services, for (final p in hintPorts) ?PortHints.hintFor(p)?.label}.toList()
      ..sort();
    final sources = <String>[
      if (h.isSelf) 'This device' else if (h.rttMs != null) 'Ping',
      if (h.viaArpOnly || (h.mac != null && !h.isSelf)) 'ARP',
      if (probe?.mdns != null || mdns != null) 'mDNS',
      if (upnp != null) 'UPnP',
      if (probe?.netbios != null) 'NetBIOS',
      if (routerName != null) 'Router DNS',
      if (probe?.dns != null && routerName == null) 'DNS',
      if (hintPorts.isNotEmpty) 'Ports',
    ];
    final identity =
        upnp?.udn ?? (mdns?.name == null ? null : 'mdns:${mdns!.name}') ?? (hostname == null ? null : 'host:$hostname');
    return h.copyWith(
      mac: mac,
      hostname: hostname,
      vendor: oui?.vendor(mac) ?? upnp?.manufacturer,
      friendlyName: friendly,
      model: model,
      deviceKind: upnp?.deviceKind,
      services: services,
      hintPorts: hintPorts,
      sources: sources,
      identity: identity,
    );
  }

  /// "[TV] Samsung Q60 Series (55)" → "Samsung Q60 Series (55)"; drops names
  /// that are only an address.
  static String? cleanFriendlyName(String? n) {
    if (n == null) return null;
    final s = n.replaceFirst(RegExp(r'^\[[^\]]{1,12}\]\s*'), '').trim();
    if (s.isEmpty || RegExp(r'^(\d{1,3}\.){3}\d{1,3}$').hasMatch(s)) return null;
    return s;
  }

  /// Apple model ids to names people know ("MacBookPro18,1" → "MacBook Pro").
  static String? prettyModel(String? model) {
    if (model == null || model.isEmpty) return null;
    const names = {
      'MacBookPro': 'MacBook Pro',
      'MacBookAir': 'MacBook Air',
      'MacBook': 'MacBook',
      'Macmini': 'Mac mini',
      'MacPro': 'Mac Pro',
      'iMac': 'iMac',
      'iPhone': 'iPhone',
      'iPad': 'iPad',
      'AppleTV': 'Apple TV',
      'AudioAccessory': 'HomePod',
      'Watch': 'Apple Watch',
    };
    final m = RegExp(r'^([A-Za-z]+)\d+,\d+$').firstMatch(model);
    if (m != null && names.containsKey(m[1])) return names[m[1]];
    if (RegExp(r'^Mac\d+,\d+$').hasMatch(model)) return 'Mac';
    return model;
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
