import '../../../core/format.dart';
import '../../../services/net/traceroute.dart';

/// Where a hop sits on the path. Derived only from data the trace has: private
/// ranges (LAN / ISP), and the Geo IP country code for public hops.
enum TraceZoneKind { lan, isp, country, unknown }

class TraceZone {
  const TraceZone(this.kind, [this.code]);
  final TraceZoneKind kind;

  /// Country code for [TraceZoneKind.country].
  final String? code;

  /// Pill text ("LAN", "ISP", "SG"), or null when nothing is known.
  String? get label => switch (kind) {
    TraceZoneKind.lan => 'LAN',
    TraceZoneKind.isp => 'ISP',
    TraceZoneKind.country => code,
    TraceZoneKind.unknown => null,
  };

  bool get isPublic => kind == TraceZoneKind.country || kind == TraceZoneKind.unknown;

  @override
  bool operator ==(Object other) => other is TraceZone && other.kind == kind && other.code == code;

  @override
  int get hashCode => Object.hash(kind, code);
}

enum TraceHighlightKind { firstHop, spike, timeouts, jump, destination }

/// One row of the "Highlights" list.
class TraceHighlight {
  const TraceHighlight({
    required this.kind,
    required this.lead,
    required this.title,
    required this.subtitle,
    this.ms,
    this.pill,
    this.noReply = false,
  });

  final TraceHighlightKind kind;

  /// Text inside the lead shape ("01", "9·10").
  final String lead;
  final String title;
  final String subtitle;

  /// Trailing latency, when there is one.
  final double? ms;

  /// Trailing pink pill instead of a latency ("+55 ms").
  final String? pill;

  /// Draw the lead as a dashed "no reply" ring.
  final bool noReply;
}

/// Two-digit hop number ("01", "21").
String hopNo(int n) => n.toString().padLeft(2, '0');

/// Probe times as "3.9 / 4.5 / 4.7 ms" ("*" for a lost probe).
String probesText(TraceHop h) {
  if (h.probes.isEmpty) return '';
  if (h.probes.every((p) => p == null)) return 'No reply to ${h.probes.length} probes';
  return '${h.probes.map((p) => p == null ? '*' : fmtMs(p)).join(' / ')} ms';
}

bool isPrivateIp(String ip) =>
    ip.startsWith('10.') ||
    ip.startsWith('192.168.') ||
    ip.startsWith('127.') ||
    ip.startsWith('169.254.') ||
    RegExp(r'^172\.(1[6-9]|2\d|3[01])\.').hasMatch(ip) ||
    RegExp(r'^100\.(6[4-9]|[7-9]\d|1[01]\d|12[0-7])\.').hasMatch(ip);

/// Home-network ranges (a second router at home is usually 192.168/172.16).
bool _isHomeRange(String ip) =>
    ip.startsWith('192.168.') || ip.startsWith('169.254.') || RegExp(r'^172\.(1[6-9]|2\d|3[01])\.').hasMatch(ip);

/// Rebuilds a hop from the JSON stored in a History session payload
/// (`payload['hops']`, written by [TraceHop.toJson]).
TraceHop traceHopFromJson(Map<String, Object?> j) {
  final h = TraceHop((j['n'] as num).toInt())
    ..ip = j['ip'] as String?
    ..host = j['host'] as String?
    ..countryCode = j['cc'] as String?
    ..city = j['city'] as String?
    ..reached = j['reached'] == true
    ..done = true;
  h.probes.addAll([for (final p in (j['probes'] as List? ?? const [])) (p as num?)?.toDouble()]);
  return h;
}

/// Everything the traceroute UI derives from a list of hops: zones, the
/// biggest jump, local spikes, timeouts, route labels and the highlights.
class TraceInsights {
  TraceInsights._({
    required this.hops,
    required this.target,
    required this.reached,
    required this.finished,
    required this.zones,
    required this.jump,
    required this.spike,
  });

  factory TraceInsights.of(
    List<TraceHop> hops, {
    required String target,
    required bool reached,
    required bool finished,
  }) {
    // Zones: the home run (hop 1 plus following home-range hops) is LAN, later
    // private hops belong to the ISP, public hops use their Geo IP country.
    final zones = <TraceZone>[];
    var home = true;
    for (final h in hops) {
      final ip = h.ip;
      if (ip == null) {
        zones.add(const TraceZone(TraceZoneKind.unknown));
        continue;
      }
      if (isPrivateIp(ip)) {
        if (home && (h.n == 1 || _isHomeRange(ip))) {
          zones.add(const TraceZone(TraceZoneKind.lan));
        } else {
          home = false;
          zones.add(const TraceZone(TraceZoneKind.isp));
        }
        continue;
      }
      home = false;
      final cc = h.countryCode;
      zones.add(
        cc == null || cc == 'LAN' ? const TraceZone(TraceZoneKind.unknown) : TraceZone(TraceZoneKind.country, cc),
      );
    }

    // Local spike: a hop more than 2x both replying neighbours (not the first
    // hop or the destination), at least 2 ms above them.
    TraceHop? spike;
    var spikeBy = 0.0;
    final lastIndex = hops.length - 1;
    for (var i = 1; i < hops.length; i++) {
      final a = hops[i].avg;
      if (a == null || (reached && i == lastIndex)) continue;
      double? prev, next;
      for (var k = i - 1; k >= 0 && prev == null; k--) {
        prev = hops[k].avg;
      }
      for (var k = i + 1; k < hops.length && next == null; k++) {
        next = hops[k].avg;
      }
      if (prev == null || next == null) continue;
      if (a > 2 * prev && a > 2 * next) {
        final by = a - (prev > next ? prev : next);
        if (by >= 2 && by > spikeBy) {
          spike = hops[i];
          spikeBy = by;
        }
      }
    }

    return TraceInsights._(
      hops: hops,
      target: target,
      reached: reached,
      finished: finished,
      zones: zones,
      jump: biggestJump(hops),
      spike: spike,
    );
  }

  final List<TraceHop> hops;
  final String target;
  final bool reached;
  final bool finished;

  /// One zone per hop, same order as [hops].
  final List<TraceZone> zones;

  /// Largest RTT increase between consecutive replying hops.
  final ({int from, int to, double addMs, String text})? jump;

  /// Hop more than 2x its neighbours, if any.
  final TraceHop? spike;

  bool get isEmpty => hops.isEmpty;

  /// Number of the hop being probed while a trace runs.
  int get probingHop {
    for (final h in hops) {
      if (!h.done) return h.n;
    }
    return hops.isEmpty ? 1 : hops.last.n + 1;
  }

  /// Hops drawn as "no reply": no address at all, or an address whose every
  /// RTT probe timed out (`* / * / *`). Matches the rail and the hop list.
  int get timeoutCount => timeouts.length;
  List<TraceHop> get timeouts => hops.where((h) => h.timedOut || (h.done && h.avg == null)).toList();
  TraceHop? get destination => reached && hops.isNotEmpty ? hops.last : null;

  /// RTT of the destination, or of the last hop that replied.
  double? get total {
    for (final h in hops.reversed) {
      if (h.avg != null) return h.avg;
    }
    return null;
  }

  TraceZone zoneOf(TraceHop h) {
    final i = hops.indexOf(h);
    return i < 0 ? const TraceZone(TraceZoneKind.unknown) : zones[i];
  }

  int? _firstPublicCountry() {
    for (var i = 0; i < hops.length; i++) {
      if (zones[i].kind == TraceZoneKind.country) return i;
    }
    return null;
  }

  int? _lastPublicCountry() {
    for (var i = hops.length - 1; i >= 0; i--) {
      if (zones[i].kind == TraceZoneKind.country) return i;
    }
    return null;
  }

  /// "BD → SG", "SG", or null without Geo IP data.
  String? get routeLabel {
    final a = _firstPublicCountry(), b = _lastPublicCountry();
    if (a == null || b == null) return null;
    final from = zones[a].code!, to = zones[b].code!;
    return from == to ? from : '$from → $to';
  }

  String _place(TraceHop h) => h.city ?? h.countryCode ?? h.ip ?? 'hop ${h.n}';

  /// Rail label under the first public hop ("Dhaka" / "BD").
  ({int index, String label})? get originLabel {
    final a = _firstPublicCountry();
    if (a == null) return null;
    return (index: a, label: _place(hops[a]));
  }

  /// Rail label under the last hop ("Singapore").
  String? get destinationLabel {
    if (hops.isEmpty) return null;
    final last = hops.last;
    if (last.city != null || (last.countryCode != null && last.countryCode != 'LAN')) return _place(last);
    return null;
  }

  /// "Hop 08 → 11 adds | 55 ms | , leaving your ISP …" for the explanation card.
  ({String before, String bold, String after})? get jumpSentence {
    final j = jump;
    if (j == null) return null;
    final from = hops.firstWhere((h) => h.n == j.from);
    final to = hops.firstWhere((h) => h.n == j.to);
    final fromZone = zoneOf(from).kind, toZone = zoneOf(to).kind;
    final String tail;
    if (fromZone == TraceZoneKind.lan && toZone == TraceZoneKind.lan) {
      tail = 'That is inside your home network, so check the Wi-Fi and the router.';
    } else if (fromZone == TraceZoneKind.lan) {
      tail = 'That is your line to the ISP.';
    } else {
      tail = 'That is outside your network, so it is outside your control.';
    }
    return (
      before: 'Hop ${hopNo(j.from)} → ${hopNo(j.to)} adds ',
      bold: '${fmtMs(j.addMs)} ms',
      after: ', ${j.text}. $tail',
    );
  }

  String _zonePhrase(TraceZone z) => switch (z.kind) {
    TraceZoneKind.lan => 'on your home network',
    TraceZoneKind.isp => 'inside the ISP',
    TraceZoneKind.country => 'in ${z.code}',
    TraceZoneKind.unknown => 'at this router',
  };

  /// Timeout lead text: "9·10", "9", "9–12", or the count when scattered.
  String _timeoutLead(List<TraceHop> t) {
    final contiguous = t.last.n - t.first.n == t.length - 1;
    if (!contiguous) return '${t.length}';
    if (t.length == 1) return '${t.first.n}';
    if (t.length == 2) return '${t.first.n}·${t.last.n}';
    return '${t.first.n}–${t.last.n}';
  }

  List<TraceHighlight> get highlights {
    if (hops.isEmpty) return const [];
    final out = <TraceHighlight>[];
    final first = hops.first;
    final firstZone = zones.first;
    if (first.timedOut) {
      out.add(
        TraceHighlight(
          kind: TraceHighlightKind.firstHop,
          lead: hopNo(1),
          title: 'Router',
          subtitle: "First hop doesn't answer probes",
          noReply: true,
        ),
      );
    } else if (first.done || first.avg != null) {
      final a = first.avg;
      out.add(
        TraceHighlight(
          kind: TraceHighlightKind.firstHop,
          lead: hopNo(1),
          title: first.host ?? (firstZone.kind == TraceZoneKind.lan ? 'Router' : first.ip ?? 'Hop 1'),
          subtitle: a == null
              ? 'First hop'
              : a < 10
              ? 'First hop is healthy'
              : a <= 40
              ? 'First hop is a little slow'
              : 'Slow first hop: check the Wi-Fi',
          ms: a,
        ),
      );
    }
    final s = spike;
    if (s != null) {
      out.add(
        TraceHighlight(
          kind: TraceHighlightKind.spike,
          lead: hopNo(s.n),
          title: s.host ?? s.ip ?? 'Hop ${s.n}',
          subtitle: '${s.avg! < 40 ? 'Small spike' : 'Spike'} ${_zonePhrase(zoneOf(s))}',
          ms: s.avg,
        ),
      );
    }
    final t = timeouts;
    if (t.isNotEmpty && !(t.length == 1 && t.first.n == 1)) {
      final rest = t.where((h) => h.n != 1).toList();
      out.add(
        TraceHighlight(
          kind: TraceHighlightKind.timeouts,
          lead: _timeoutLead(rest),
          title: 'No reply',
          subtitle: '${rest.length} hop${rest.length == 1 ? '' : 's'}, probes timed out',
          noReply: true,
        ),
      );
    }
    final j = jump;
    if (j != null) {
      out.add(
        TraceHighlight(
          kind: TraceHighlightKind.jump,
          lead: hopNo(j.to),
          title: 'Biggest jump',
          subtitle: 'Hop ${hopNo(j.from)} → ${hopNo(j.to)}',
          pill: '+${fmtMs(j.addMs)} ms',
        ),
      );
    }
    final last = hops.last;
    if (reached) {
      final place = destinationLabel;
      out.add(
        TraceHighlight(
          kind: TraceHighlightKind.destination,
          lead: hopNo(last.n),
          title: target.isEmpty ? (last.host ?? last.ip ?? 'Destination') : target,
          subtitle: place != null ? 'Reached in $place' : 'Reached in ${hops.length} hops',
          ms: last.avg,
        ),
      );
    } else if (finished) {
      out.add(
        TraceHighlight(
          kind: TraceHighlightKind.destination,
          lead: hopNo(last.n),
          title: target.isEmpty ? 'Destination' : target,
          subtitle: 'Not reached within ${hops.length} hops',
          noReply: true,
        ),
      );
    }
    return out;
  }

  /// Accessible one-line summary of the route.
  String get semanticSummary {
    final b = StringBuffer('Route of ${hops.length} hops');
    if (timeoutCount > 0) b.write(', $timeoutCount without reply');
    final j = jump;
    if (j != null) b.write(', biggest jump plus ${fmtMs(j.addMs)} ms at hop ${j.to}');
    final t = total;
    if (reached && t != null) b.write(', destination reached in ${fmtMs(t)} ms');
    return b.toString();
  }
}
