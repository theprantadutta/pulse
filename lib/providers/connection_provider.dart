import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:network_info_plus/network_info_plus.dart';

/// Connection kind shown in the sidebar footer and headers.
enum LinkKind { wifi, ethernet, cellular, vpn, other, none }

class ConnectionSummary {
  const ConnectionSummary({required this.kind, this.name, this.localIp, this.interfaceName, this.vpn = false});

  final LinkKind kind;

  /// SSID for Wi-Fi, adapter name otherwise.
  final String? name;
  final String? localIp;
  final String? interfaceName;
  final bool vpn;

  bool get online => kind != LinkKind.none;

  String get kindLabel => switch (kind) {
    LinkKind.wifi => 'WIFI',
    LinkKind.ethernet => 'ETHERNET',
    LinkKind.cellular => 'CELLULAR',
    LinkKind.vpn => 'VPN',
    LinkKind.other => 'NETWORK',
    LinkKind.none => 'OFFLINE',
  };

  static const offline = ConnectionSummary(kind: LinkKind.none);
}

/// Picks the best local IPv4: private ranges first, skipping loopback,
/// link-local and virtual adapters.
Future<(String, String)?> primaryLocalIpv4() async {
  final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4, includeLinkLocal: false);
  bool isVirtual(String n) {
    final l = n.toLowerCase();
    return l.contains('vethernet') ||
        l.contains('virtualbox') ||
        l.contains('vmware') ||
        l.contains('docker') ||
        l.contains('wsl') ||
        l.contains('hyper-v') ||
        l.startsWith('br-') ||
        l.startsWith('veth') ||
        l.startsWith('utun') ||
        l.startsWith('lo');
  }

  bool isPrivate(String ip) =>
      ip.startsWith('10.') || ip.startsWith('192.168.') || RegExp(r'^172\.(1[6-9]|2\d|3[01])\.').hasMatch(ip);

  (String, String)? fallback;
  for (final iface in interfaces) {
    if (isVirtual(iface.name)) continue;
    for (final a in iface.addresses) {
      if (a.isLoopback) continue;
      if (isPrivate(a.address)) return (a.address, iface.name);
      fallback ??= (a.address, iface.name);
    }
  }
  return fallback;
}

Future<ConnectionSummary> readConnection(List<ConnectivityResult> results) async {
  if (results.isEmpty || results.every((r) => r == ConnectivityResult.none)) {
    return ConnectionSummary.offline;
  }
  final vpn = results.contains(ConnectivityResult.vpn);
  final kind = results.contains(ConnectivityResult.wifi)
      ? LinkKind.wifi
      : results.contains(ConnectivityResult.ethernet)
      ? LinkKind.ethernet
      : results.contains(ConnectivityResult.mobile)
      ? LinkKind.cellular
      : vpn
      ? LinkKind.vpn
      : LinkKind.other;

  final info = NetworkInfo();
  String? name;
  String? ip;
  if (kind == LinkKind.wifi) {
    try {
      name = (await info.getWifiName())?.replaceAll('"', '');
      ip = await info.getWifiIP();
    } catch (_) {}
  }
  final primary = await primaryLocalIpv4();
  ip ??= primary?.$1;
  if (name == null || name.isEmpty || name == '<unknown ssid>') {
    name = primary?.$2;
  }
  return ConnectionSummary(kind: kind, name: name, localIp: ip, interfaceName: primary?.$2, vpn: vpn);
}

/// Live connection summary; refreshes whenever connectivity changes.
final connectionProvider = StreamProvider<ConnectionSummary>((ref) async* {
  final connectivity = Connectivity();
  yield await readConnection(await connectivity.checkConnectivity());
  await for (final results in connectivity.onConnectivityChanged) {
    yield await readConnection(results);
  }
});
