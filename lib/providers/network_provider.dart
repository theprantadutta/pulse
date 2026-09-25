import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../services/net/geo_ip.dart';
import '../services/net/network_details.dart';
import 'connection_provider.dart';
import 'ping_provider.dart';
import 'settings_provider.dart';

final geoIpServiceProvider = Provider<GeoIpService>((ref) => GeoIpService());

final networkDetailsReaderProvider = Provider<NetworkDetailsReader>((ref) => const NetworkDetailsReader());

@immutable
class NetworkSnapshot {
  const NetworkSnapshot({
    required this.link,
    required this.updatedAt,
    this.geo,
    this.geoError,
    this.gatewayPingMs,
    this.dnsPingMs,
    this.publicIpv6,
    this.internetLoading = true,
    this.lookupsDisabled = false,
  });

  final LinkDetails link;
  final DateTime updatedAt;
  final GeoInfo? geo;
  final String? geoError;
  final double? gatewayPingMs;
  final double? dnsPingMs;
  final String? publicIpv6;
  final bool internetLoading;

  /// Settings → Privacy turned public-IP lookups off.
  final bool lookupsDisabled;

  NetworkSnapshot copyWith({
    GeoInfo? geo,
    String? geoError,
    double? gatewayPingMs,
    double? dnsPingMs,
    String? publicIpv6,
    bool? internetLoading,
  }) => NetworkSnapshot(
    link: link,
    updatedAt: updatedAt,
    geo: geo ?? this.geo,
    geoError: geoError ?? this.geoError,
    gatewayPingMs: gatewayPingMs ?? this.gatewayPingMs,
    dnsPingMs: dnsPingMs ?? this.dnsPingMs,
    publicIpv6: publicIpv6 ?? this.publicIpv6,
    internetLoading: internetLoading ?? this.internetLoading,
    lookupsDisabled: lookupsDisabled,
  );

  /// Plain-text dump for COPY ALL.
  String toText() {
    final l = link;
    String row(String k, Object? v) => '${k.padRight(12)}${v ?? '—'}';
    return [
      'PULSE · NETWORK · $updatedAt',
      row('Connection', [l.kind.name.toUpperCase(), l.name].whereType<String>().join(' · ')),
      row(
        'Standard',
        [l.standard, l.band, if (l.channel != null) 'CH ${l.channel}', l.security].whereType<String>().join(' · '),
      ),
      row('Signal', l.signalDbm == null ? null : '${l.signalDbm} dBm'),
      row('Link speed', l.linkMbps == null ? null : '${l.linkMbps} Mbps'),
      row('Local IPv4', l.localIpv4),
      row('Subnet', l.subnetCidr),
      row('Gateway', l.gateway),
      row('DNS 1', l.dns.firstOrNull),
      row('DNS 2', l.dns.length > 1 ? l.dns[1] : null),
      row('MAC', l.mac),
      row('IPv6', l.ipv6.firstOrNull),
      row('VPN', l.vpn ? 'ON${l.vpnName == null ? '' : ' (${l.vpnName})'}' : 'OFF'),
      row('Public IP', geo?.ip),
      row('ISP', geo?.isp),
      row('ASN', geo?.asn),
      row('Location', geo?.place),
      row('GW ping', gatewayPingMs == null ? null : '${gatewayPingMs!.toStringAsFixed(1)} ms'),
      row('DNS ping', dnsPingMs == null ? null : '${dnsPingMs!.toStringAsFixed(1)} ms'),
      row('IPv6 net', publicIpv6 ?? 'not available'),
    ].join('\n');
  }
}

final networkInfoProvider = AsyncNotifierProvider<NetworkInfoNotifier, NetworkSnapshot>(NetworkInfoNotifier.new);

class NetworkInfoNotifier extends AsyncNotifier<NetworkSnapshot> {
  int _generation = 0;

  @override
  Future<NetworkSnapshot> build() async {
    // Re-read whenever the connection changes (new Wi-Fi, cable, VPN…).
    ref.listen(connectionProvider, (prev, next) {
      final a = prev?.value, b = next.value;
      if (a != null &&
          b != null &&
          (a.kind != b.kind || a.name != b.name || a.localIp != b.localIp || a.vpn != b.vpn)) {
        refresh();
      }
    });
    return _load();
  }

  /// Re-reads everything; the previous snapshot stays visible meanwhile.
  void refresh() => ref.invalidateSelf();

  Future<NetworkSnapshot> _load() async {
    final gen = ++_generation;
    final link = await ref.read(networkDetailsReaderProvider).read();
    final lookups = ref.read(settingsProvider).publicIpLookups;
    final snap = NetworkSnapshot(
      link: link,
      updatedAt: DateTime.now(),
      lookupsDisabled: !lookups,
      internetLoading: link.kind != LinkKind.none,
    );
    if (link.kind != LinkKind.none) _loadInternet(snap, gen, lookups);
    return snap;
  }

  /// Fills the INTERNET table in the background so the link shows at once.
  Future<void> _loadInternet(NetworkSnapshot base, int gen, bool lookups) async {
    final prober = ref.read(pingProberProvider);
    var snap = base;
    void push(NetworkSnapshot s) {
      if (gen != _generation) return;
      snap = s;
      state = AsyncData(s);
    }

    Future<double?> ping(String? host) async {
      if (host == null) return null;
      final r = await prober.probe(host, timeout: const Duration(seconds: 2));
      return r.ok ? r.rttMs : null;
    }

    final service = ref.read(geoIpServiceProvider);
    await Future.wait([
      ping(base.link.gateway).then((v) => push(snap.copyWith(gatewayPingMs: v))),
      ping(base.link.dns.firstOrNull).then((v) => push(snap.copyWith(dnsPingMs: v))),
      if (lookups)
        service
            .lookup()
            .then((g) => push(snap.copyWith(geo: g)))
            .catchError((Object e) => push(snap.copyWith(geoError: '$e'))),
      if (lookups) service.publicIpv6().then((v) => push(snap.copyWith(publicIpv6: v))),
    ]);
    push(snap.copyWith(internetLoading: false));
  }
}
