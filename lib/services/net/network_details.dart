import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/services.dart';
import 'package:network_info_plus/network_info_plus.dart';

import '../../providers/connection_provider.dart';
import 'gateway.dart';

/// Everything the Network screen shows about the local link.
class LinkDetails {
  const LinkDetails({
    required this.kind,
    this.name,
    this.interfaceName,
    this.adapter,
    this.ssid,
    this.bssid,
    this.standard,
    this.band,
    this.channel,
    this.security,
    this.rssiDbm,
    this.signalPercent,
    this.linkMbps,
    this.localIpv4,
    this.prefixLength,
    this.gateway,
    this.dns = const [],
    this.mac,
    this.ipv6 = const [],
    this.vpn = false,
    this.vpnName,
    this.ssidNeedsPermission = false,
  });

  final LinkKind kind;
  final String? name;
  final String? interfaceName;
  final String? adapter;
  final String? ssid;
  final String? bssid;

  /// "WI-FI 6", "WI-FI 5", …
  final String? standard;

  /// "2.4 GHZ", "5 GHZ", "6 GHZ".
  final String? band;
  final int? channel;

  /// "WPA3", "WPA2", "OPEN", …
  final String? security;
  final int? rssiDbm;
  final int? signalPercent;
  final int? linkMbps;
  final String? localIpv4;
  final int? prefixLength;
  final String? gateway;
  final List<String> dns;
  final String? mac;
  final List<String> ipv6;
  final bool vpn;
  final String? vpnName;

  /// The OS hides the SSID until location access is granted.
  final bool ssidNeedsPermission;

  /// 0–4 blocks for the signal meter.
  int get signalBars {
    final dbm = rssiDbm ?? (signalPercent == null ? null : signalPercent! ~/ 2 - 100);
    if (dbm == null) return 0;
    if (dbm >= -55) return 4;
    if (dbm >= -65) return 3;
    if (dbm >= -75) return 2;
    if (dbm >= -85) return 1;
    return 0;
  }

  /// Signal in dBm, derived from the percentage when the OS only gives that.
  int? get signalDbm => rssiDbm ?? (signalPercent == null ? null : signalPercent! ~/ 2 - 100);

  String? get subnetCidr {
    if (localIpv4 == null || prefixLength == null) return null;
    final parts = localIpv4!.split('.').map(int.parse).toList();
    final ip = (parts[0] << 24) | (parts[1] << 16) | (parts[2] << 8) | parts[3];
    final mask = prefixLength == 0 ? 0 : (0xFFFFFFFF << (32 - prefixLength!)) & 0xFFFFFFFF;
    final net = ip & mask;
    return '${(net >> 24) & 255}.${(net >> 16) & 255}.${(net >> 8) & 255}.${net & 255}/$prefixLength';
  }
}

String? bandFromMhz(int? mhz) {
  if (mhz == null || mhz <= 0) return null;
  if (mhz < 3000) return '2.4 GHZ';
  if (mhz < 5925) return '5 GHZ';
  return '6 GHZ';
}

int? channelFromMhz(int? mhz) {
  if (mhz == null || mhz <= 0) return null;
  if (mhz == 2484) return 14;
  if (mhz < 3000) return (mhz - 2407) ~/ 5;
  if (mhz >= 5955) return (mhz - 5950) ~/ 5;
  return (mhz - 5000) ~/ 5;
}

String? standardFromPhy(String? phy) {
  if (phy == null) return null;
  final p = phy.toLowerCase();
  if (p.contains('be')) return 'WI-FI 7';
  if (p.contains('ax')) return 'WI-FI 6';
  if (p.contains('ac')) return 'WI-FI 5';
  if (p.contains('11n') || p.endsWith('n')) return 'WI-FI 4';
  if (p.contains('11g') || p.endsWith('g')) return 'WI-FI 3';
  if (p.contains('11a') || p.contains('11b')) return 'WI-FI 1/2';
  return null;
}

String? securityLabel(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  final r = raw.toUpperCase();
  if (r.contains('WPA3') || r.contains('SAE')) return 'WPA3';
  if (r.contains('WPA2') || r.contains('RSN')) return 'WPA2';
  if (r.contains('WPA')) return 'WPA';
  if (r.contains('WEP')) return 'WEP';
  if (r.contains('OPEN') || r.contains('NONE')) return 'OPEN';
  if (r.contains('OWE')) return 'OWE';
  return r.split(RegExp(r'[\s-]')).first;
}

int prefixFromMask(String mask) {
  var bits = 0;
  for (final part in mask.split('.')) {
    var v = int.tryParse(part) ?? 0;
    while (v > 0) {
      bits += v & 1;
      v >>= 1;
    }
  }
  return bits;
}

/// Reads [LinkDetails] from the current OS.
class NetworkDetailsReader {
  const NetworkDetailsReader();

  static const _channel = MethodChannel('network_info');

  /// [summary] lets tests skip the connectivity plugin.
  Future<LinkDetails> read({ConnectionSummary? summary}) async {
    summary ??= await readConnection(await Connectivity().checkConnectivity());
    if (!summary.online) return const LinkDetails(kind: LinkKind.none);
    if (Platform.isWindows) return _windows(summary);
    if (Platform.isLinux) return _linux(summary);
    if (Platform.isMacOS) return _macos(summary);
    if (Platform.isAndroid) return _android(summary);
    return _ios(summary);
  }

  // ------------------------------------------------------------- Windows

  static const _windowsScript = r'''
$ErrorActionPreference = 'SilentlyContinue'
$c = Get-CimInstance Win32_NetworkAdapterConfiguration -Filter 'IPEnabled=True' | Where-Object { $_.DefaultIPGateway } | Sort-Object IPConnectionMetric | Select-Object -First 1
if (-not $c) { '{}'; exit }
$ad = Get-CimInstance Win32_NetworkAdapter -Filter "Index=$($c.Index)"
$vpn = Get-CimInstance Win32_NetworkAdapter -Filter 'NetEnabled=True' | Where-Object { $_.Description -match 'VPN|WireGuard|TAP-|TUN|OpenVPN|Tailscale|ZeroTier|AnyConnect|Fortinet|GlobalProtect|Wintun' } | Select-Object -First 1
[pscustomobject]@{
  alias = $ad.NetConnectionID; description = $c.Description; ips = @($c.IPAddress); masks = @($c.IPSubnet)
  gateway = @($c.DefaultIPGateway); dns = @($c.DNSServerSearchOrder); mac = $c.MACAddress; speed = $ad.Speed
  vpn = [bool]$vpn; vpnName = $vpn.NetConnectionID
} | ConvertTo-Json -Compress
''';

  Future<LinkDetails> _windows(ConnectionSummary s) async {
    final ps = await Process.run('powershell', [
      '-NoProfile',
      '-NonInteractive',
      '-ExecutionPolicy',
      'Bypass',
      '-Command',
      _windowsScript,
    ]);
    Map<String, dynamic> j = {};
    try {
      j = jsonDecode('${ps.stdout}'.trim()) as Map<String, dynamic>;
    } on Object {
      j = {};
    }
    List<String> list(Object? v) =>
        v == null ? const [] : (v is List ? v.map((e) => '$e').toList() : ['$v']);
    final ips = list(j['ips']);
    final masks = list(j['masks']);
    String? v4;
    int? prefix;
    for (var i = 0; i < ips.length; i++) {
      if (ips[i].contains('.')) {
        v4 = ips[i];
        if (i < masks.length) prefix = prefixFromMask(masks[i]);
        break;
      }
    }
    final ipv6 = ips.where((a) => a.contains(':') && !a.toLowerCase().startsWith('fe80')).toList();
    final speed = j['speed'];

    String? ssid, bssid, radio, auth, band;
    int? channel, signal, rx;
    if (s.kind == LinkKind.wifi) {
      final w = await Process.run('netsh', ['wlan', 'show', 'interfaces']);
      for (final line in '${w.stdout}'.split('\n')) {
        final i = line.indexOf(':');
        if (i < 0) continue;
        final key = line.substring(0, i).trim().toLowerCase();
        final value = line.substring(i + 1).trim();
        if (key == 'ssid') {
          ssid = value;
        } else if (key == 'bssid' || key.startsWith('ap bssid')) {
          bssid = value;
        } else if (key.startsWith('radio type') || RegExp(r'^802\.11\w+$').hasMatch(value)) {
          radio = value;
        } else if (key.startsWith('authentication') || RegExp(r'^(WPA|Open|WEP)', caseSensitive: false).hasMatch(value)) {
          auth ??= value;
        } else if (key == 'channel') {
          channel = int.tryParse(value);
        } else if (key == 'band') {
          band = value.toUpperCase().replaceAll('GHZ', ' GHZ').replaceAll('  ', ' ');
        } else if (key.startsWith('signal') || RegExp(r'^\d{1,3}%$').hasMatch(value)) {
          signal = int.tryParse(value.replaceAll('%', '').trim());
        } else if (key.startsWith('receive rate')) {
          rx = double.tryParse(value)?.round();
        }
      }
      band ??= channel == null ? null : (channel > 14 ? '5 GHZ' : '2.4 GHZ');
    }
    return LinkDetails(
      kind: s.kind,
      name: ssid ?? j['alias'] as String? ?? s.name,
      interfaceName: j['alias'] as String?,
      adapter: j['description'] as String?,
      ssid: ssid,
      bssid: bssid,
      standard: standardFromPhy(radio),
      band: band,
      channel: channel,
      security: securityLabel(auth),
      signalPercent: signal,
      linkMbps: rx ?? (speed is num ? (speed / 1000000).round() : null),
      localIpv4: v4 ?? s.localIp,
      prefixLength: prefix,
      gateway: list(j['gateway']).where((g) => g.contains('.')).firstOrNull,
      dns: list(j['dns']),
      mac: (j['mac'] as String?)?.replaceAll('-', ':').toUpperCase(),
      ipv6: ipv6,
      vpn: j['vpn'] == true || s.vpn,
      vpnName: j['vpnName'] as String?,
    );
  }

  // --------------------------------------------------------------- Linux

  Future<LinkDetails> _linux(ConnectionSummary s) async {
    final route = await Process.run('ip', ['-j', '-4', 'route', 'show', 'default']);
    String? dev, gw;
    try {
      final r = (jsonDecode('${route.stdout}') as List).cast<Map>().first;
      dev = r['dev'] as String?;
      gw = r['gateway'] as String?;
    } on Object {
      gw = await Gateway.ipv4();
    }
    String? v4;
    int? prefix;
    final v6 = <String>[];
    if (dev != null) {
      final addr = await Process.run('ip', ['-j', 'addr', 'show', 'dev', dev]);
      try {
        final info = (jsonDecode('${addr.stdout}') as List).cast<Map>().first;
        for (final a in (info['addr_info'] as List).cast<Map>()) {
          if (a['family'] == 'inet' && v4 == null) {
            v4 = a['local'] as String?;
            prefix = a['prefixlen'] as int?;
          } else if (a['family'] == 'inet6' && a['scope'] == 'global') {
            v6.add(a['local'] as String);
          }
        }
      } on Object {
        // Leave the fields empty when `ip -j` is unavailable.
      }
    }
    final dns = <String>[];
    final resolved = await Process.run('resolvectl', ['dns', ?dev]);
    for (final m in RegExp(r'((?:\d{1,3}\.){3}\d{1,3})').allMatches('${resolved.stdout}')) {
      dns.add(m.group(1)!);
    }
    if (dns.isEmpty) {
      try {
        for (final line in await File('/etc/resolv.conf').readAsLines()) {
          final m = RegExp(r'^nameserver\s+(\S+)').firstMatch(line.trim());
          if (m != null && !m.group(1)!.startsWith('127.')) dns.add(m.group(1)!);
        }
      } on Object {
        // No resolv.conf readable.
      }
    }
    String? mac;
    int? speed;
    if (dev != null) {
      try {
        mac = (await File('/sys/class/net/$dev/address').readAsString()).trim().toUpperCase();
      } on Object {
        mac = null;
      }
      try {
        speed = int.tryParse((await File('/sys/class/net/$dev/speed').readAsString()).trim());
      } on Object {
        speed = null;
      }
    }

    String? ssid, security, band, standard;
    int? channel, rssi, rate, freq;
    if (s.kind == LinkKind.wifi) {
      final nm = await Process.run('nmcli', ['-t', '-f', 'IN-USE,SSID,CHAN,FREQ,RATE,SIGNAL,SECURITY', 'dev', 'wifi']);
      for (final line in '${nm.stdout}'.split('\n')) {
        if (!line.startsWith('*')) continue;
        final f = line.replaceAll(r'\:', '\u0000').split(':').map((e) => e.replaceAll('\u0000', ':')).toList();
        if (f.length >= 7) {
          ssid = f[1];
          channel = int.tryParse(f[2]);
          freq = int.tryParse(f[3].split(' ').first);
          rate = int.tryParse(f[4].split(' ').first);
          security = securityLabel(f[6]);
        }
      }
      if (dev != null) {
        final iw = await Process.run('iw', ['dev', dev, 'link']);
        final out = '${iw.stdout}';
        rssi = int.tryParse(RegExp(r'signal:\s*(-?\d+)').firstMatch(out)?.group(1) ?? '');
        freq ??= int.tryParse(RegExp(r'freq:\s*(\d+)').firstMatch(out)?.group(1) ?? '');
        ssid ??= RegExp(r'SSID:\s*(.+)').firstMatch(out)?.group(1)?.trim();
        final tx = RegExp(r'tx bitrate:\s*([\d.]+) MBit/s(.*)').firstMatch(out);
        rate ??= double.tryParse(tx?.group(1) ?? '')?.round();
        final mode = tx?.group(2) ?? '';
        standard = mode.contains('EHT')
            ? 'WI-FI 7'
            : mode.contains('HE-')
            ? 'WI-FI 6'
            : mode.contains('VHT')
            ? 'WI-FI 5'
            : mode.contains('MCS')
            ? 'WI-FI 4'
            : null;
      }
      band = bandFromMhz(freq);
      channel ??= channelFromMhz(freq);
    }
    return LinkDetails(
      kind: s.kind,
      name: ssid ?? dev ?? s.name,
      interfaceName: dev,
      ssid: ssid,
      standard: standard,
      band: band,
      channel: channel,
      security: security,
      rssiDbm: rssi,
      linkMbps: rate ?? (speed != null && speed > 0 ? speed : null),
      localIpv4: v4 ?? s.localIp,
      prefixLength: prefix,
      gateway: gw,
      dns: dns,
      mac: mac,
      ipv6: v6,
      vpn: s.vpn || (await _hasTunnel()),
    );
  }

  Future<bool> _hasTunnel() async {
    final ifaces = await NetworkInterface.list(includeLoopback: false);
    return ifaces.any((i) {
      final n = i.name.toLowerCase();
      return n.startsWith('tun') || n.startsWith('wg') || n.startsWith('ppp') || n.startsWith('tailscale') || n.startsWith('utun') || n.startsWith('ipsec');
    });
  }

  // --------------------------------------------------------------- macOS

  Future<LinkDetails> _macos(ConnectionSummary s) async {
    final route = await Process.run('/sbin/route', ['-n', 'get', 'default']);
    final out = '${route.stdout}';
    final gw = RegExp(r'gateway:\s*(\S+)').firstMatch(out)?.group(1);
    final dev = RegExp(r'interface:\s*(\S+)').firstMatch(out)?.group(1);
    String? v4, mac;
    int? prefix;
    final v6 = <String>[];
    if (dev != null) {
      final ifc = '${(await Process.run('/sbin/ifconfig', [dev])).stdout}';
      final inet = RegExp(r'inet ((?:\d{1,3}\.){3}\d{1,3}) netmask 0x([0-9a-f]{8})').firstMatch(ifc);
      if (inet != null) {
        v4 = inet.group(1);
        prefix = int.parse(inet.group(2)!, radix: 16).toRadixString(2).replaceAll('0', '').length;
      }
      mac = RegExp(r'ether ([0-9a-f:]{17})').firstMatch(ifc)?.group(1)?.toUpperCase();
      for (final m in RegExp(r'inet6 ([0-9a-f:]+)[^\n]*').allMatches(ifc)) {
        final a = m.group(1)!;
        if (!a.startsWith('fe80') && !m.group(0)!.contains('temporary')) v6.add(a);
      }
    }
    final dns = <String>[];
    final scutil = '${(await Process.run('/usr/sbin/scutil', ['--dns'])).stdout}';
    for (final m in RegExp(r'nameserver\[\d+\]\s*:\s*(\S+)').allMatches(scutil)) {
      if (!dns.contains(m.group(1))) dns.add(m.group(1)!);
    }

    String? ssid, security, band, standard;
    int? channel, rssi, rate;
    if (s.kind == LinkKind.wifi) {
      final sp = await Process.run('/usr/sbin/system_profiler', ['SPAirPortDataType', '-json']);
      try {
        final root = jsonDecode('${sp.stdout}') as Map<String, dynamic>;
        final ifaces = ((root['SPAirPortDataType'] as List).first as Map)['spairport_airport_interfaces'] as List;
        for (final i in ifaces.cast<Map>()) {
          final cur = i['spairport_current_network_information'];
          if (cur is! Map) continue;
          final name = cur['_name'] as String?;
          if (name != null && !name.contains('redacted')) ssid = name;
          final ch = '${cur['spairport_network_channel'] ?? ''}';
          channel = int.tryParse(RegExp(r'^(\d+)').firstMatch(ch)?.group(1) ?? '');
          band = ch.contains('6GHz')
              ? '6 GHZ'
              : ch.contains('5GHz')
              ? '5 GHZ'
              : ch.contains('2GHz')
              ? '2.4 GHZ'
              : null;
          standard = standardFromPhy('${cur['spairport_network_phymode'] ?? ''}');
          security = securityLabel('${cur['spairport_security_mode'] ?? ''}'.replaceAll('spairport_security_mode_', ''));
          rssi = int.tryParse(RegExp(r'(-\d+) dBm').firstMatch('${cur['spairport_signal_noise'] ?? ''}')?.group(1) ?? '');
          rate = (cur['spairport_network_rate'] as num?)?.round();
        }
      } on Object {
        // system_profiler output unavailable; keep the basic fields.
      }
    }
    return LinkDetails(
      kind: s.kind,
      name: ssid ?? dev ?? s.name,
      interfaceName: dev,
      ssid: ssid,
      standard: standard,
      band: band,
      channel: channel,
      security: security,
      rssiDbm: rssi,
      linkMbps: rate,
      localIpv4: v4 ?? s.localIp,
      prefixLength: prefix,
      gateway: gw,
      dns: dns,
      mac: mac,
      ipv6: v6,
      vpn: s.vpn || await _hasTunnel(),
      ssidNeedsPermission: s.kind == LinkKind.wifi && ssid == null,
    );
  }

  // ------------------------------------------------------------- Android

  Future<LinkDetails> _android(ConnectionSummary s) async {
    Map<Object?, Object?> m = const {};
    try {
      m = await _channel.invokeMapMethod<Object?, Object?>('getNetworkDetails') ?? const {};
    } on PlatformException {
      m = const {};
    }
    final freq = m['frequency'] as int?;
    final ssid = (m['ssid'] as String?)?.replaceAll('"', '');
    final hidden = ssid == null || ssid == '<unknown ssid>';
    return LinkDetails(
      kind: s.kind,
      name: hidden ? s.name : ssid,
      interfaceName: m['interface'] as String?,
      ssid: hidden ? null : ssid,
      bssid: m['bssid'] as String?,
      standard: _androidStandard(m['wifiStandard'] as int?),
      band: bandFromMhz(freq),
      channel: channelFromMhz(freq),
      security: m['security'] as String?,
      rssiDbm: m['rssi'] as int?,
      linkMbps: m['linkSpeed'] as int?,
      localIpv4: m['ipv4'] as String? ?? s.localIp,
      prefixLength: m['prefix'] as int?,
      gateway: m['gateway'] as String?,
      dns: ((m['dns'] as List?) ?? const []).cast<String>(),
      mac: m['mac'] as String?,
      ipv6: ((m['ipv6'] as List?) ?? const []).cast<String>(),
      vpn: m['vpn'] == true || s.vpn,
      ssidNeedsPermission: s.kind == LinkKind.wifi && hidden,
    );
  }

  static String? _androidStandard(int? s) => switch (s) {
    4 => 'WI-FI 4',
    5 => 'WI-FI 5',
    6 => 'WI-FI 6',
    7 => 'WIGIG',
    8 => 'WI-FI 7',
    _ => null,
  };

  // ----------------------------------------------------------------- iOS

  Future<LinkDetails> _ios(ConnectionSummary s) async {
    final info = NetworkInfo();
    String? ssid, bssid, mask, gw;
    try {
      ssid = (await info.getWifiName())?.replaceAll('"', '');
      bssid = await info.getWifiBSSID();
      mask = await info.getWifiSubmask();
      gw = await info.getWifiGatewayIP();
    } on Object {
      ssid = null;
    }
    Map<Object?, Object?> m = const {};
    try {
      m = await _channel.invokeMapMethod<Object?, Object?>('getNetworkDetails') ?? const {};
    } on PlatformException {
      m = const {};
    }
    final v6 = <String>[];
    for (final i in await NetworkInterface.list(type: InternetAddressType.IPv6)) {
      if (i.name != s.interfaceName) continue;
      for (final a in i.addresses) {
        if (!a.isLinkLocal) v6.add(a.address);
      }
    }
    return LinkDetails(
      kind: s.kind,
      name: ssid ?? s.name,
      interfaceName: s.interfaceName,
      ssid: ssid,
      bssid: bssid,
      security: m['security'] as String?,
      localIpv4: s.localIp,
      prefixLength: mask == null ? null : prefixFromMask(mask),
      gateway: gw ?? await Gateway.ipv4(),
      dns: ((m['dns'] as List?) ?? const []).cast<String>(),
      ipv6: v6,
      vpn: s.vpn || m['vpn'] == true,
      ssidNeedsPermission: s.kind == LinkKind.wifi && ssid == null,
    );
  }
}
