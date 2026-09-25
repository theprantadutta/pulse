import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../data/models/session_tool.dart';
import '../services/net/dns.dart';
import '../services/net/ping_prober.dart';
import '../services/background/monitor_engine.dart';
import 'alerts_provider.dart';
import 'ping_provider.dart';

enum PacketState { pending, ok, late, lost }

/// Replies slower than this count as LATE.
const kLateMs = 150.0;

@immutable
class LossRun {
  const LossRun({required this.packets, required this.rtts});

  /// One entry per scheduled packet.
  final List<PacketState> packets;
  final List<double?> rtts;

  int get sent => packets.where((p) => p != PacketState.pending).length;
  int get lost => packets.where((p) => p == PacketState.lost).length;
  int get late => packets.where((p) => p == PacketState.late).length;
  double get lossPct => sent == 0 ? 0 : lost / sent * 100;

  double? get avgRtt {
    final v = rtts.whereType<double>().toList();
    return v.isEmpty ? null : v.reduce((a, b) => a + b) / v.length;
  }

  int get longestBurst {
    var best = 0, cur = 0;
    for (final p in packets) {
      if (p == PacketState.lost) {
        cur++;
        best = math.max(best, cur);
      } else if (p != PacketState.pending) {
        cur = 0;
      }
    }
    return best;
  }

  /// Start indexes of loss bursts (2+ consecutive lost packets).
  List<int> get burstStarts {
    final out = <int>[];
    var run = 0;
    for (var i = 0; i < packets.length; i++) {
      if (packets[i] == PacketState.lost) {
        run++;
        if (run == 2) out.add(i - 1);
      } else {
        run = 0;
      }
    }
    return out;
  }
}

@immutable
class LossState {
  const LossState({
    this.target = '',
    this.address,
    this.durationMin = 5,
    this.ratePerSec = 1,
    this.run = const LossRun(packets: [], rtts: []),
    this.compare,
    this.running = false,
    this.startedAt,
    this.error,
  });

  final String target;
  final String? address;
  final int durationMin;
  final int ratePerSec;
  final LossRun run;

  /// Parallel run against 1.1.1.1 for comparison.
  final LossRun? compare;
  final bool running;
  final DateTime? startedAt;
  final String? error;

  int get total => durationMin * 60 * ratePerSec;
  Duration get elapsed => startedAt == null ? Duration.zero : DateTime.now().difference(startedAt!);

  LossState copyWith({
    String? target,
    String? address,
    int? durationMin,
    int? ratePerSec,
    LossRun? run,
    LossRun? compare,
    bool? running,
    DateTime? startedAt,
    String? error,
    bool clearError = false,
    bool clearCompare = false,
  }) => LossState(
    target: target ?? this.target,
    address: address ?? this.address,
    durationMin: durationMin ?? this.durationMin,
    ratePerSec: ratePerSec ?? this.ratePerSec,
    run: run ?? this.run,
    compare: clearCompare ? null : compare ?? this.compare,
    running: running ?? this.running,
    startedAt: startedAt ?? this.startedAt,
    error: clearError ? null : error ?? this.error,
  );
}

/// One-word verdict plus a plain-language explanation.
({String word, String text}) lossVerdict(LossState s) {
  final r = s.run;
  if (r.sent < 10) return (word: 'measuring', text: 'Collecting enough packets to judge the link…');
  final loss = r.lossPct;
  final latePct = r.late / r.sent * 100;
  final bursts = r.burstStarts;
  String? pattern;
  if (bursts.length >= 3) {
    final gaps = [for (var i = 1; i < bursts.length; i++) (bursts[i] - bursts[i - 1]) / s.ratePerSec];
    final mean = gaps.reduce((a, b) => a + b) / gaps.length;
    final sd = math.sqrt(gaps.map((g) => math.pow(g - mean, 2)).reduce((a, b) => a + b) / gaps.length);
    if (sd / mean < 0.35) {
      pattern = 'Loss comes in bursts every ~${mean.round()} s — typical of Wi-Fi interference, not the server.';
    } else {
      pattern = 'Loss comes in irregular bursts — look at Wi-Fi signal or a congested uplink.';
    }
  } else if (r.lost > 0) {
    pattern = r.longestBurst <= 1
        ? 'Drops are isolated single packets — mild congestion along the path.'
        : 'A short outage dropped ${r.longestBurst} packets in a row.';
  }
  String? compareText;
  final c = s.compare;
  if (c != null && c.sent >= 10) {
    if (c.lossPct < 0.5 && loss >= 1) {
      compareText = '1.1.1.1 is clean at ${c.lossPct.toStringAsFixed(1)}% — the loss is specific to ${s.target}.';
    } else if (c.lossPct >= 1) {
      compareText = '1.1.1.1 also loses ${c.lossPct.toStringAsFixed(1)}% — the problem is on your side (Wi-Fi or ISP).';
    } else {
      compareText = '1.1.1.1 is clean too.';
    }
  }
  final word = loss == 0 && latePct < 1
      ? 'stable'
      : loss < 1 && latePct < 5
      ? 'good'
      : loss < 5
      ? 'unstable'
      : 'poor';
  final base = switch (word) {
    'stable' => 'No loss and latency is steady.',
    'good' => 'Only occasional drops.',
    'unstable' => pattern ?? 'Noticeable loss for games and calls.',
    _ => pattern ?? 'Heavy loss — calls and games will stutter.',
  };
  final late = latePct >= 5 ? ' ${latePct.toStringAsFixed(0)}% of replies were late (>150 ms).' : '';
  return (word: word, text: [base + late, ?compareText].join(' '));
}

final lossProvider = NotifierProvider<LossNotifier, LossState>(LossNotifier.new);

class LossNotifier extends Notifier<LossState> {
  Timer? _timer;
  Timer? _ticker;
  int _generation = 0;

  @override
  LossState build() {
    ref.onDispose(_cancelTimers);
    return const LossState();
  }

  void _cancelTimers() {
    _timer?.cancel();
    _ticker?.cancel();
  }

  void setDuration(int min) => state = state.copyWith(durationMin: min);
  void setRate(int r) => state = state.copyWith(ratePerSec: r);

  Future<void> start(String target) async {
    target = target.trim();
    if (target.isEmpty || state.running) return;
    _cancelTimers();
    final gen = ++_generation;
    String address;
    try {
      address = (await Dns.resolve(target, family: ProbeFamily.ipv4)).address;
    } on DnsFailure catch (e) {
      state = state.copyWith(target: target, error: '$e');
      return;
    }
    final total = state.durationMin * 60 * state.ratePerSec;
    state = LossState(
      target: target,
      address: address,
      durationMin: state.durationMin,
      ratePerSec: state.ratePerSec,
      run: LossRun(packets: List.filled(total, PacketState.pending), rtts: List.filled(total, null)),
      running: true,
      startedAt: DateTime.now(),
    );
    final prober = ref.read(pingProberProvider);
    var seq = 0;
    final interval = Duration(milliseconds: 1000 ~/ state.ratePerSec);
    _timer = Timer.periodic(interval, (t) {
      if (gen != _generation || seq >= total) {
        t.cancel();
        return;
      }
      final i = seq++;
      prober.probe(address, timeout: const Duration(seconds: 2)).then((r) => _record(gen, i, r, compare: false));
      if (state.compare != null) {
        prober.probe('1.1.1.1', timeout: const Duration(seconds: 2)).then((r) => _record(gen, i, r, compare: true));
      }
    });
    // Keeps the elapsed clock moving between replies.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (gen == _generation && state.running) state = state.copyWith();
    });
  }

  void _record(int gen, int i, ProbeResult r, {required bool compare}) {
    if (gen != _generation) return;
    final run = compare ? state.compare : state.run;
    if (run == null || i >= run.packets.length) return;
    final packets = List.of(run.packets);
    final rtts = List.of(run.rtts);
    packets[i] = !r.ok
        ? PacketState.lost
        : (r.rttMs ?? 0) > kLateMs
        ? PacketState.late
        : PacketState.ok;
    rtts[i] = r.ok ? r.rttMs : null;
    final next = LossRun(packets: packets, rtts: rtts);
    state = compare ? state.copyWith(compare: next) : state.copyWith(run: next);
    if (!compare && !next.packets.contains(PacketState.pending)) _finish();
  }

  /// Starts pinging 1.1.1.1 alongside the target from now on.
  void compareToCloudflare() {
    if (!state.running || state.compare != null) return;
    // Packets sent before the comparison started stay pending, so they are
    // excluded from 1.1.1.1's stats.
    final total = state.total;
    state = state.copyWith(
      compare: LossRun(packets: List.filled(total, PacketState.pending), rtts: List.filled(total, null)),
    );
  }

  Future<void> stop() async {
    if (!state.running) return;
    _finish();
  }

  Future<void> _finish() async {
    _cancelTimers();
    _generation++;
    final s = state;
    state = s.copyWith(running: false);
    if (s.run.sent == 0) return;
    final v = lossVerdict(s);
    await ref
        .read(historyRepositoryProvider)
        .save(
          tool: SessionTool.loss,
          target: s.target,
          startedAt: s.startedAt!,
          endedAt: DateTime.now(),
          avgMs: s.run.avgRtt,
          lossPct: s.run.lossPct,
          summary: '${s.run.lossPct.toStringAsFixed(1)}% · ${v.word}',
          payload: {
            'address': s.address,
            'rate': s.ratePerSec,
            'sent': s.run.sent,
            'lost': s.run.lost,
            'late': s.run.late,
            'burst': s.run.longestBurst,
            'verdict': v.text,
            'packets': [
              for (var i = 0; i < s.run.sent; i++) {'seq': i + 1, 'state': s.run.packets[i].name, 'rtt': s.run.rtts[i]},
            ],
          },
        );
  }

  /// SET ALERT ON LOSS: a rule that fires when loss stays above the level
  /// seen here (at least 1%) for a minute.
  Future<int> createLossAlert() async {
    final threshold = math.max(1.0, (state.run.lossPct).floorToDouble());
    return ref
        .read(alertRulesRepositoryProvider)
        .save(
          RuleDraft(
            title: 'Packet loss · ${state.target}',
            target: state.target,
            metric: AlertMetric.loss,
            threshold: threshold,
            forSeconds: 60,
          ),
        );
  }

  /// CSV of every packet so far.
  String toCsv() {
    final b = StringBuffer('seq,state,rtt_ms\n');
    final r = state.run;
    for (var i = 0; i < r.packets.length; i++) {
      if (r.packets[i] == PacketState.pending) continue;
      b.writeln('${i + 1},${r.packets[i].name},${r.rtts[i]?.toStringAsFixed(1) ?? ''}');
    }
    return b.toString();
  }
}
