import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'dns.dart';
import 'ping_prober.dart';

class TraceHop {
  TraceHop(this.n);

  final int n;
  String? ip;
  String? host;
  String? countryCode;
  String? city;

  /// One entry per probe; null = no answer.
  final probes = <double?>[];
  bool reached = false;
  bool done = false;

  bool get timedOut => done && ip == null;

  double? get avg {
    final v = probes.whereType<double>().toList();
    return v.isEmpty ? null : v.reduce((a, b) => a + b) / v.length;
  }

  Map<String, Object?> toJson() => {
    'n': n,
    'ip': ip,
    'host': host,
    'cc': countryCode,
    'city': city,
    'probes': probes,
    'reached': reached,
  };
}

class TraceResult {
  const TraceResult({
    required this.target,
    required this.destination,
    required this.hops,
    required this.reached,
    required this.finished,
  });

  final String target;
  final String destination;
  final List<TraceHop> hops;
  final bool reached;
  final bool finished;
}

/// TTL-stepping traceroute built on [PingProber] so it runs on every
/// platform without raw sockets.
class Traceroute {
  Traceroute({this.prober = const PingProber(), http.Client? client}) : _client = client ?? http.Client();

  final PingProber prober;
  final http.Client _client;

  Stream<TraceResult> run(
    String target, {
    int maxHops = 30,
    int probes = 3,
    Duration timeout = const Duration(seconds: 2),
    bool geo = true,
  }) async* {
    final dest = (await Dns.resolve(target, family: ProbeFamily.ipv4)).address;
    final hops = <int, TraceHop>{};
    var reachedAt = maxHops + 1;
    final updates = StreamController<void>();
    var next = 1;
    var active = 0;
    const window = 6;
    final exactHopRtt = Platform.isWindows;

    Future<void> runHop(int ttl) async {
      final hop = hops[ttl] = TraceHop(ttl);
      for (var i = 0; i < probes; i++) {
        if (ttl > reachedAt) break;
        final r = await prober.probe(dest, ttl: ttl, timeout: timeout, packetSize: 32);
        if (r.status == ProbeStatus.ok) {
          hop.ip ??= r.from ?? dest;
          hop.reached = true;
          hop.probes.add(r.rttMs);
          if (ttl < reachedAt) reachedAt = ttl;
        } else if (r.status == ProbeStatus.ttlExceeded || (r.status == ProbeStatus.unreachable && r.from != null)) {
          hop.ip ??= r.from;
          hop.probes.add(exactHopRtt ? r.rttMs : null);
        } else {
          hop.probes.add(null);
        }
        updates.add(null);
      }
      // System ping gives no time on "TTL exceeded": time the hop directly.
      if (!exactHopRtt && hop.ip != null && !hop.reached && hop.probes.every((p) => p == null)) {
        hop.probes.clear();
        for (var i = 0; i < probes; i++) {
          final r = await prober.probe(hop.ip!, timeout: timeout, packetSize: 32);
          hop.probes.add(r.ok ? r.rttMs : null);
        }
      }
      hop.done = true;
      final ip = hop.ip;
      if (ip != null) {
        Dns.reverse(ip).then((name) {
          hop.host = name;
          if (!updates.isClosed) updates.add(null);
        });
      }
      updates.add(null);
    }

    void pump() {
      while (active < window && next <= maxHops && next <= reachedAt) {
        final ttl = next++;
        active++;
        runHop(ttl).whenComplete(() {
          active--;
          if ((next > maxHops || next > reachedAt) && active == 0) {
            // Give pending PTR lookups a moment before closing.
            Future<void>.delayed(const Duration(milliseconds: 600), updates.close);
          } else {
            pump();
          }
        });
      }
    }

    List<TraceHop> snapshot() {
      final last = reachedAt <= maxHops
          ? reachedAt
          : (hops.keys.isEmpty ? 0 : hops.keys.reduce((a, b) => a > b ? a : b));
      return [for (var t = 1; t <= last; t++) ?hops[t]];
    }

    pump();
    await for (final _ in updates.stream) {
      yield TraceResult(
        target: target,
        destination: dest,
        hops: snapshot(),
        reached: reachedAt <= maxHops,
        finished: false,
      );
    }
    final finalHops = snapshot();
    if (geo) await _locate(finalHops);
    yield TraceResult(
      target: target,
      destination: dest,
      hops: finalHops,
      reached: reachedAt <= maxHops,
      finished: true,
    );
  }

  /// One ip-api batch call for every public hop.
  Future<void> _locate(List<TraceHop> hops) async {
    final public = <String>{
      for (final h in hops)
        if (h.ip != null && !_isPrivate(h.ip!)) h.ip!,
    }.toList();
    for (final h in hops) {
      if (h.ip != null && _isPrivate(h.ip!)) h.countryCode = 'LAN';
    }
    if (public.isEmpty) return;
    try {
      final res = await _client
          .post(Uri.parse('http://ip-api.com/batch?fields=status,query,countryCode,city'), body: jsonEncode(public))
          .timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) return;
      final byIp = {
        for (final e in (jsonDecode(res.body) as List).cast<Map>())
          if (e['status'] == 'success') e['query'] as String: e,
      };
      for (final h in hops) {
        final e = byIp[h.ip];
        if (e != null) {
          h.countryCode = e['countryCode'] as String?;
          h.city = e['city'] as String?;
        }
      }
    } on Object {
      // Locations are optional; the trace itself is complete.
    }
  }

  static bool _isPrivate(String ip) =>
      ip.startsWith('10.') ||
      ip.startsWith('192.168.') ||
      ip.startsWith('127.') ||
      ip.startsWith('169.254.') ||
      RegExp(r'^172\.(1[6-9]|2\d|3[01])\.').hasMatch(ip) ||
      RegExp(r'^100\.(6[4-9]|[7-9]\d|1[01]\d|12[0-7])\.').hasMatch(ip);
}

/// Plain-language insight for the largest latency increase along a path.
({int from, int to, double addMs, String text})? biggestJump(List<TraceHop> hops) {
  TraceHop? prev;
  ({int from, int to, double addMs, String text})? best;
  for (final h in hops) {
    final a = h.avg;
    if (a == null) continue;
    if (prev != null) {
      final d = a - prev.avg!;
      if (best == null || d > best.addMs) {
        String where() {
          String place(TraceHop x) => x.city ?? x.countryCode ?? x.ip ?? 'hop ${x.n}';
          if (prev!.countryCode == 'LAN') {
            if (prev.n == 1) return 'leaving your home network';
            if (h.countryCode == 'LAN') return "inside your ISP's private network";
            return 'leaving your ISP for the public internet';
          }
          if (prev.countryCode != null && h.countryCode != null && prev.countryCode != h.countryCode) {
            return 'the link from ${place(prev)} to ${place(h)}';
          }
          if (h.countryCode != null) return 'inside ${h.city ?? h.countryCode}';
          return 'between ${prev.ip} and ${h.ip}';
        }

        best = (from: prev.n, to: h.n, addMs: d, text: where());
      }
    }
    prev = h;
  }
  return best == null || best.addMs <= 0 ? null : best;
}
