import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../data/models/session_tool.dart';
import '../services/net/dns.dart';
import '../services/net/geo_ip.dart';
import '../services/net/ping_prober.dart';
import 'network_provider.dart';
import 'ping_provider.dart';
import 'settings_provider.dart';

@immutable
class GeoState {
  const GeoState({
    this.query = '',
    this.resolvedIp,
    this.target,
    this.me,
    this.rttMs,
    this.hops,
    this.loading = false,
    this.error,
  });

  final String query;
  final String? resolvedIp;
  final GeoInfo? target;
  final GeoInfo? me;
  final double? rttMs;
  final int? hops;
  final bool loading;
  final String? error;

  double? get distanceKm {
    final a = me, b = target;
    if (a?.lat == null || a?.lon == null || b?.lat == null || b?.lon == null) return null;
    return haversineKm(a!.lat!, a.lon!, b!.lat!, b.lon!);
  }

  GeoState copyWith({
    String? query,
    String? resolvedIp,
    GeoInfo? target,
    GeoInfo? me,
    double? rttMs,
    int? hops,
    bool? loading,
    String? error,
    bool clearError = false,
    bool clearResult = false,
  }) => GeoState(
    query: query ?? this.query,
    resolvedIp: clearResult ? resolvedIp : resolvedIp ?? this.resolvedIp,
    target: clearResult ? target : target ?? this.target,
    me: me ?? this.me,
    rttMs: clearResult ? rttMs : rttMs ?? this.rttMs,
    hops: clearResult ? hops : hops ?? this.hops,
    loading: loading ?? this.loading,
    error: clearError ? error : error ?? this.error,
  );
}

double haversineKm(double lat1, double lon1, double lat2, double lon2) {
  const r = 6371.0;
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(lat2 - lat1);
  final dLon = rad(lon2 - lon1);
  final a = math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(lat1)) * math.cos(rad(lat2)) * math.pow(math.sin(dLon / 2), 2);
  return 2 * r * math.asin(math.sqrt(a));
}

/// Routers along the path, from the reply TTL and the usual initial TTLs.
int? hopsFromTtl(int? ttl) {
  if (ttl == null || ttl <= 0) return null;
  final initial = ttl > 128 ? 255 : ttl > 64 ? 128 : 64;
  return initial - ttl + 1;
}

bool _tzReady = false;

/// "UTC+8", "UTC−5:30" for an IANA zone name.
String? utcOffsetLabel(String? zone) {
  if (zone == null) return null;
  if (!_tzReady) {
    tzdata.initializeTimeZones();
    _tzReady = true;
  }
  try {
    final offset = tz.TZDateTime.now(tz.getLocation(zone)).timeZoneOffset;
    final sign = offset.isNegative ? '−' : '+';
    final m = offset.inMinutes.abs();
    return 'UTC$sign${m ~/ 60}${m % 60 == 0 ? '' : ':${(m % 60).toString().padLeft(2, '0')}'}';
  } on Object {
    return null;
  }
}

bool isPrivateIp(String ip) {
  final a = InternetAddress.tryParse(ip);
  if (a == null) return false;
  if (a.isLoopback || a.isLinkLocal) return true;
  if (a.type == InternetAddressType.IPv4) {
    return ip.startsWith('10.') ||
        ip.startsWith('192.168.') ||
        RegExp(r'^172\.(1[6-9]|2\d|3[01])\.').hasMatch(ip) ||
        RegExp(r'^100\.(6[4-9]|[7-9]\d|1[01]\d|12[0-7])\.').hasMatch(ip);
  }
  return ip.toLowerCase().startsWith('fc') || ip.toLowerCase().startsWith('fd');
}

final geoProvider = NotifierProvider<GeoNotifier, GeoState>(GeoNotifier.new);

class GeoNotifier extends Notifier<GeoState> {
  @override
  GeoState build() => const GeoState();

  Future<GeoInfo?> _me() async {
    if (state.me != null) return state.me;
    final snap = ref.read(networkInfoProvider).value;
    if (snap?.geo != null) return snap!.geo;
    try {
      return await ref.read(geoIpServiceProvider).lookup();
    } on Object {
      return null;
    }
  }

  Future<void> locateMe() async {
    state = state.copyWith(loading: true, clearError: true);
    final me = await _me();
    if (me == null) {
      state = state.copyWith(loading: false, error: 'Could not determine your public IP.');
      return;
    }
    await locate(me.ip);
  }

  Future<void> locate(String query) async {
    query = query.trim();
    if (query.isEmpty) return;
    if (!ref.read(settingsProvider).publicIpLookups) {
      state = state.copyWith(query: query, error: 'Public IP lookups are turned off in Settings → Privacy.');
      return;
    }
    state = GeoState(query: query, me: state.me, loading: true);
    final started = DateTime.now();
    String ip;
    try {
      ip = (await Dns.resolve(query, family: ProbeFamily.ipv4)).address;
    } on DnsFailure catch (e) {
      state = state.copyWith(loading: false, error: '$e');
      return;
    }
    if (isPrivateIp(ip)) {
      state = state.copyWith(
        loading: false,
        resolvedIp: ip,
        error: '$ip is a private address — it has no public location.',
      );
      return;
    }
    state = state.copyWith(resolvedIp: ip);
    try {
      final results = await Future.wait<Object?>([
        ref.read(geoIpServiceProvider).lookup(ip),
        _me(),
        ref.read(pingProberProvider).probe(ip, timeout: const Duration(seconds: 3)),
      ]);
      final target = results[0]! as GeoInfo;
      final me = results[1] as GeoInfo?;
      final probe = results[2]! as ProbeResult;
      state = state.copyWith(
        target: target,
        me: me,
        rttMs: probe.ok ? probe.rttMs : null,
        hops: probe.ok ? hopsFromTtl(probe.ttl) : null,
        loading: false,
      );
      await ref.read(historyRepositoryProvider).save(
        tool: SessionTool.geo,
        target: query,
        startedAt: started,
        endedAt: DateTime.now(),
        avgMs: state.rttMs,
        summary: target.city ?? target.country ?? target.ip,
        payload: {'geo': target.toJson(), 'distanceKm': state.distanceKm, 'hops': state.hops},
      );
    } on Object catch (e) {
      state = state.copyWith(loading: false, error: '$e');
    }
  }
}
