import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../data/models/ping_models.dart';
import '../data/models/session_tool.dart';
import '../services/net/dns.dart';
import '../services/net/traceroute.dart';
import 'ping_provider.dart';
import 'settings_provider.dart';

@immutable
class TraceState {
  const TraceState({
    this.target = '',
    this.destination,
    this.hops = const [],
    this.running = false,
    this.reached = false,
    this.finished = false,
    this.maxHops = 30,
    this.probes = 3,
    this.error,
    this.startedAt,
  });

  final String target;
  final String? destination;
  final List<TraceHop> hops;
  final bool running;
  final bool reached;
  final bool finished;
  final int maxHops;
  final int probes;
  final String? error;
  final DateTime? startedAt;

  double? get totalRtt => hops.isEmpty ? null : hops.lastWhere((h) => h.avg != null, orElse: () => hops.last).avg;
  int get timeouts => hops.where((h) => h.timedOut).length;

  /// Distinct country codes along the path, with the latency each border adds.
  List<({String cc, double? addMs})> get route {
    final out = <({String cc, double? addMs})>[];
    double? lastAvg;
    for (final h in hops) {
      final cc = h.countryCode;
      if (cc == null || cc == 'LAN') {
        lastAvg = h.avg ?? lastAvg;
        continue;
      }
      if (out.isEmpty || out.last.cc != cc) {
        out.add((cc: cc, addMs: h.avg != null && lastAvg != null ? h.avg! - lastAvg : null));
      }
      lastAvg = h.avg ?? lastAvg;
    }
    return out;
  }

  TraceState copyWith({
    String? target,
    String? destination,
    List<TraceHop>? hops,
    bool? running,
    bool? reached,
    bool? finished,
    int? maxHops,
    int? probes,
    String? error,
    DateTime? startedAt,
    bool clearError = false,
  }) => TraceState(
    target: target ?? this.target,
    destination: destination ?? this.destination,
    hops: hops ?? this.hops,
    running: running ?? this.running,
    reached: reached ?? this.reached,
    finished: finished ?? this.finished,
    maxHops: maxHops ?? this.maxHops,
    probes: probes ?? this.probes,
    error: clearError ? null : error ?? this.error,
    startedAt: startedAt ?? this.startedAt,
  );

  /// Text report for COPY / SAVE.
  String toText() {
    final b = StringBuffer('PULSE TRACEROUTE $target (${destination ?? '?'})\n');
    for (final h in hops) {
      final probesText = h.probes.map((p) => p == null ? '*' : '${p.toStringAsFixed(1)} ms').join('  ');
      b.writeln('${h.n.toString().padLeft(2)}  ${(h.ip ?? '*').padRight(16)} ${(h.host ?? '').padRight(42)} $probesText  ${h.countryCode ?? ''}');
    }
    b.writeln(reached ? 'Destination reached in ${hops.length} hops.' : 'Destination not reached.');
    return b.toString();
  }
}

final tracerouteProvider = Provider<Traceroute>((ref) => Traceroute(prober: ref.watch(pingProberProvider)));

final traceProvider = NotifierProvider<TraceNotifier, TraceState>(TraceNotifier.new);

class TraceNotifier extends Notifier<TraceState> {
  StreamSubscription<TraceResult>? _sub;

  @override
  TraceState build() {
    ref.onDispose(() => _sub?.cancel());
    return const TraceState();
  }

  void setMaxHops(int v) => state = state.copyWith(maxHops: v);
  void setProbes(int v) => state = state.copyWith(probes: v);

  Future<void> run(String target) async {
    target = target.trim();
    if (target.isEmpty) return;
    await _sub?.cancel();
    final started = DateTime.now();
    state = TraceState(target: target, running: true, maxHops: state.maxHops, probes: state.probes, startedAt: started);
    final geo = ref.read(settingsProvider).publicIpLookups;
    final done = Completer<void>();
    _sub = ref
        .read(tracerouteProvider)
        .run(target, maxHops: state.maxHops, probes: state.probes, geo: geo)
        .listen(
          (r) => state = state.copyWith(
            destination: r.destination,
            hops: List.of(r.hops),
            reached: r.reached,
            finished: r.finished,
          ),
          onError: (Object e) {
            state = state.copyWith(
              running: false,
              finished: true,
              error: e is DnsFailure ? '$e' : 'Traceroute failed: $e',
            );
            if (!done.isCompleted) done.complete();
          },
          onDone: () {
            if (!done.isCompleted) done.complete();
          },
        );
    await done.future;
    state = state.copyWith(running: false, finished: true);
    if (state.error == null && state.hops.isNotEmpty) await _save(started);
  }

  Future<void> stop() async {
    await _sub?.cancel();
    state = state.copyWith(running: false, finished: true);
  }

  Future<void> _save(DateTime started) async {
    final s = state;
    final route = s.route.map((r) => r.cc).join(' → ');
    await ref.read(historyRepositoryProvider).save(
      tool: SessionTool.trace,
      target: s.target,
      startedAt: started,
      endedAt: DateTime.now(),
      avgMs: s.totalRtt,
      lossPct: s.hops.isEmpty ? null : s.timeouts / s.hops.length * 100,
      summary: '${s.hops.length} hops${s.reached ? '' : ' · not reached'}${route.isEmpty ? '' : ' · $route'}',
      trend: bucketAverages([for (final h in s.hops) h.avg ?? 0], 12),
      payload: {'destination': s.destination, 'reached': s.reached, 'hops': [for (final h in s.hops) h.toJson()]},
    );
  }
}
