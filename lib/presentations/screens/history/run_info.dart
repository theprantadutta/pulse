import 'package:intl/intl.dart';

import '../../../core/format.dart';
import '../../../data/db/app_database.dart';
import '../../../data/models/ping_models.dart';
import '../../../data/models/session_tool.dart';
import '../../../data/repositories/history_repository.dart';
import '../../navigation/tools_catalog.dart';

/// Tone of a summary tile in the run detail (kit: pink, lime, lavender, then a
/// neutral container).
enum RunTileTone { pink, lime, lavender, neutral }

class RunTile {
  const RunTile(this.label, this.value, {this.unit, this.tone = RunTileTone.neutral});
  final String label;
  final String value;
  final String? unit;
  final RunTileTone tone;
}

/// One traceroute hop as stored in a session payload.
class RunHop {
  const RunHop({required this.n, this.ip, this.host, this.cc, this.city, this.avg, this.reached = false});
  final int n;
  final String? ip, host, cc, city;
  final double? avg;
  final bool reached;

  bool get timedOut => ip == null;
}

/// Everything the History list and run detail show for a stored session,
/// derived from its columns and JSON payload.
class RunInfo {
  RunInfo(this.session) : kind = SessionTool.byName(session.tool), payload = HistoryRepository.payloadOf(session);

  final Session session;
  final SessionTool? kind;
  final Map<String, dynamic> payload;

  PulseTool get tool => kind == null ? kPingTool : toolForSession(kind!);

  String get title => session.label ?? session.target;

  static final _hm = DateFormat('HH:mm');
  static final _md = DateFormat('MMM d');

  String get time => _hm.format(session.startedAt);

  /// "Today 16:30", "Yesterday 09:12", "Nov 8 15:05".
  String get when {
    final now = DateTime.now();
    final d = session.startedAt;
    final diff = DateTime(now.year, now.month, now.day).difference(DateTime(d.year, d.month, d.day)).inDays;
    final day = diff == 0
        ? 'Today'
        : diff == 1
        ? 'Yesterday'
        : _md.format(d);
    return '$day $time';
  }

  Duration get duration => session.endedAt.difference(session.startedAt);

  String get durationText {
    final d = duration;
    if (d.inSeconds < 60) return '${d.inSeconds} s';
    if (d.inMinutes < 60) return '${d.inMinutes} min';
    return '${d.inHours} h ${d.inMinutes % 60} min';
  }

  // ---------------------------------------------------------------------------
  // Typed payload access
  // ---------------------------------------------------------------------------

  double? _num(String key) => (payload[key] as num?)?.toDouble();
  int? _int(String key) => (payload[key] as num?)?.toInt();
  List<Map<String, dynamic>> _list(String key) =>
      payload[key] is List ? [for (final e in payload[key] as List) (e as Map).cast<String, dynamic>()] : const [];

  PingStats? get pingStats =>
      payload['stats'] is Map ? PingStats.fromJson((payload['stats'] as Map).cast<String, dynamic>()) : null;

  List<PingReply> get pingReplies => [for (final r in _list('replies')) PingReply.fromJson(r)];

  PingParams? get pingParams =>
      payload['params'] is Map ? PingParams.fromJson((payload['params'] as Map).cast<String, dynamic>()) : null;

  List<RunHop> get hops => [
    for (final h in _list('hops'))
      RunHop(
        n: (h['n'] as num?)?.toInt() ?? 0,
        ip: h['ip'] as String?,
        host: h['host'] as String?,
        cc: h['cc'] as String?,
        city: h['city'] as String?,
        reached: h['reached'] == true,
        avg: () {
          final p = (h['probes'] as List? ?? const []).whereType<num>().map((v) => v.toDouble()).toList();
          return p.isEmpty ? null : p.reduce((a, b) => a + b) / p.length;
        }(),
      ),
  ];

  /// "BD → SG" from the hops' country codes (first and last distinct).
  String get route {
    final ccs = <String>[];
    for (final h in hops) {
      final cc = h.cc;
      if (cc == null || cc.isEmpty) continue;
      if (ccs.isEmpty || ccs.last != cc) ccs.add(cc);
    }
    if (ccs.isEmpty) return '—';
    if (ccs.length == 1) return ccs.first;
    return '${ccs.first} → ${ccs.last}';
  }

  List<Map<String, dynamic>> get openPorts => _list('open');
  List<Map<String, dynamic>> get devices => _list('devices');
  List<Map<String, dynamic>> get packets => _list('packets');
  Map<String, dynamic> get geo => payload['geo'] is Map ? (payload['geo'] as Map).cast<String, dynamic>() : const {};

  // ---------------------------------------------------------------------------
  // List row
  // ---------------------------------------------------------------------------

  /// Result on the right of a History row.
  String get result {
    switch (kind) {
      case SessionTool.ping:
        return session.avgMs == null ? 'No reply' : '${fmtMs(session.avgMs)} ms';
      case SessionTool.trace:
        return session.avgMs == null ? '${hops.length} hops' : '${fmtMs(session.avgMs)} ms';
      case SessionTool.speed:
        final down = _num('down'), up = _num('up');
        return '${down?.toStringAsFixed(0) ?? '—'} ↓ ${up?.toStringAsFixed(0) ?? '—'} ↑';
      case SessionTool.ports:
        return '${openPorts.length} open';
      case SessionTool.loss:
        return '${(session.lossPct ?? 0).toStringAsFixed(1)}%';
      case SessionTool.lan:
        final n = devices.length;
        return '$n device${n == 1 ? '' : 's'}';
      case SessionTool.geo:
        return session.summary.isEmpty ? (geo['ip'] as String? ?? '—') : session.summary;
      case null:
        return session.summary.split(' · ').first;
    }
  }

  /// Extra detail after "time · tool".
  String get detail {
    switch (kind) {
      case SessionTool.ping:
        final loss = session.lossPct ?? 0;
        return loss > 0 ? '${fmtPct(loss)} loss' : '';
      case SessionTool.trace:
        final reached = payload['reached'] != false;
        return '${hops.length} hops${reached ? '' : ' · not reached'}';
      case SessionTool.speed:
        return '';
      case SessionTool.ports:
        return (payload['range'] as String?) ?? '';
      case SessionTool.loss:
        final sent = _int('sent');
        return sent == null ? '' : '$sent sent';
      case SessionTool.lan:
        final fresh = devices.where((d) => d['new'] == true).length;
        return fresh > 0 ? '$fresh new' : '';
      case SessionTool.geo:
      case null:
        return '';
    }
  }

  String get subtitle => [time, tool.name, if (detail.isNotEmpty) detail].join(' · ');

  // ---------------------------------------------------------------------------
  // Detail summary tiles
  // ---------------------------------------------------------------------------

  List<RunTile> get tiles {
    String ms(double? v) => fmtMs(v);
    switch (kind) {
      case SessionTool.trace:
        final h = hops;
        return [
          RunTile('Total', ms(session.avgMs), unit: session.avgMs == null ? null : 'ms', tone: RunTileTone.pink),
          RunTile('Hops', '${h.length}', tone: RunTileTone.lime),
          RunTile('Route', route, tone: RunTileTone.lavender),
          RunTile('Timeouts', '${h.where((x) => x.timedOut).length}'),
        ];
      case SessionTool.ping:
        final st = pingStats;
        return [
          RunTile('Average', ms(session.avgMs), unit: session.avgMs == null ? null : 'ms', tone: RunTileTone.pink),
          RunTile('Loss', fmtPct(session.lossPct), tone: RunTileTone.lime),
          RunTile('Jitter', ms(st?.jitter), unit: st?.jitter == null ? null : 'ms', tone: RunTileTone.lavender),
          RunTile('Sent', st == null ? '—' : fmtCount(st.sent)),
        ];
      case SessionTool.speed:
        String mbps(double? v) => v == null ? '—' : v.toStringAsFixed(v < 10 ? 1 : 0);
        return [
          RunTile('Download', mbps(_num('down')), unit: 'Mbps', tone: RunTileTone.pink),
          RunTile('Upload', mbps(_num('up')), unit: 'Mbps', tone: RunTileTone.lime),
          RunTile('Ping', ms(_num('ping')), unit: _num('ping') == null ? null : 'ms', tone: RunTileTone.lavender),
          RunTile('Jitter', ms(_num('jitter')), unit: _num('jitter') == null ? null : 'ms'),
        ];
      case SessionTool.ports:
        return [
          RunTile('Open', '${openPorts.length}', tone: RunTileTone.pink),
          RunTile('Filtered', '${_int('filtered') ?? 0}', tone: RunTileTone.lavender),
          RunTile('Scanned', '${_int('scanned') ?? '—'}', tone: RunTileTone.lime),
          RunTile('Took', durationText),
        ];
      case SessionTool.loss:
        return [
          RunTile('Loss', (session.lossPct ?? 0).toStringAsFixed(1), unit: '%', tone: RunTileTone.pink),
          RunTile('Sent', '${_int('sent') ?? '—'}', tone: RunTileTone.lime),
          RunTile('Lost', '${_int('lost') ?? '—'}', tone: RunTileTone.lavender),
          RunTile('Avg', ms(session.avgMs), unit: session.avgMs == null ? null : 'ms'),
        ];
      case SessionTool.lan:
        final d = devices;
        return [
          RunTile('Devices', '${d.length}', tone: RunTileTone.lime),
          RunTile('New', '${d.where((x) => x['new'] == true).length}', tone: RunTileTone.pink),
          RunTile(
            'Named',
            '${d.where((x) => (x['name'] as String?)?.isNotEmpty ?? false).length}',
            tone: RunTileTone.lavender,
          ),
          RunTile('Took', durationText),
        ];
      case SessionTool.geo:
        final g = geo;
        final km = _num('distanceKm');
        return [
          RunTile('Place', (g['city'] as String?) ?? (g['country'] as String?) ?? '—', tone: RunTileTone.pink),
          RunTile('Country', (g['countryCode'] as String?) ?? '—', tone: RunTileTone.lime),
          RunTile('RTT', ms(session.avgMs), unit: session.avgMs == null ? null : 'ms', tone: RunTileTone.lavender),
          RunTile(
            'Distance',
            km == null ? '—' : NumberFormat.decimalPattern().format(km.round()),
            unit: km == null ? null : 'km',
          ),
        ];
      case null:
        return [
          RunTile('Result', session.summary.isEmpty ? '—' : session.summary, tone: RunTileTone.pink),
          RunTile('Took', durationText),
        ];
    }
  }

  /// Plain-language line for the run, used in semantics.
  String get semantics => '$title, ${tool.name}, $when, $result';
}

/// Groups newest-first [sessions] into days: ("Today", runs), ("Yesterday", ...).
List<(String, List<Session>)> groupByDay(List<Session> sessions, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final today = DateTime(n.year, n.month, n.day);
  final groups = <(String, List<Session>)>[];
  DateTime? current;
  for (final s in sessions) {
    final day = DateTime(s.startedAt.year, s.startedAt.month, s.startedAt.day);
    if (current != day) {
      current = day;
      final diff = today.difference(day).inDays;
      final label = diff == 0
          ? 'Today'
          : diff == 1
          ? 'Yesterday'
          : day.year == today.year
          ? DateFormat('MMM d').format(day)
          : DateFormat('MMM d, y').format(day);
      groups.add((label, <Session>[]));
    }
    groups.last.$2.add(s);
  }
  return groups;
}
