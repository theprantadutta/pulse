import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../data/db/app_database.dart';
import '../data/models/session_tool.dart';
import '../data/repositories/history_repository.dart';
import '../services/net/speed_test.dart';
import 'database_provider.dart';
import 'geo_provider.dart';
import 'network_provider.dart';
import 'ping_provider.dart';

@immutable
class SpeedState {
  const SpeedState({
    this.server = const SpeedServer(id: '', name: '', location: '', downloadUrl: '', pingUrl: ''),
    this.autoSelected = false,
    this.selecting = false,
    this.phase = SpeedPhase.idle,
    this.liveMbps,
    this.pingMs,
    this.jitterMs,
    this.downMbps,
    this.upMbps,
    this.samples = const [],
    this.progress = 0,
    this.colo,
    this.error,
  });

  final SpeedServer server;
  final bool autoSelected;
  final bool selecting;
  final SpeedPhase phase;
  final double? liveMbps;
  final double? pingMs;
  final double? jitterMs;
  final double? downMbps;
  final double? upMbps;
  final List<SpeedSample> samples;
  final double progress;
  final String? colo;
  final String? error;

  bool get running => phase != SpeedPhase.idle && phase != SpeedPhase.done;
  bool get hasServer => server.id.isNotEmpty;

  SpeedState copyWith({
    SpeedServer? server,
    bool? autoSelected,
    bool? selecting,
    SpeedPhase? phase,
    double? liveMbps,
    double? pingMs,
    double? jitterMs,
    double? downMbps,
    double? upMbps,
    List<SpeedSample>? samples,
    double? progress,
    String? colo,
    String? error,
    bool clearError = false,
  }) => SpeedState(
    server: server ?? this.server,
    autoSelected: autoSelected ?? this.autoSelected,
    selecting: selecting ?? this.selecting,
    phase: phase ?? this.phase,
    liveMbps: liveMbps ?? this.liveMbps,
    pingMs: pingMs ?? this.pingMs,
    jitterMs: jitterMs ?? this.jitterMs,
    downMbps: downMbps ?? this.downMbps,
    upMbps: upMbps ?? this.upMbps,
    samples: samples ?? this.samples,
    progress: progress ?? this.progress,
    colo: colo ?? this.colo,
    error: clearError ? null : error ?? this.error,
  );
}

final speedProvider = NotifierProvider<SpeedNotifier, SpeedState>(SpeedNotifier.new);

class SpeedNotifier extends Notifier<SpeedState> {
  SpeedTest? _test;
  StreamSubscription<SpeedUpdate>? _sub;

  @override
  SpeedState build() {
    ref.onDispose(() {
      _test?.cancel();
      _sub?.cancel();
    });
    return const SpeedState();
  }

  Future<void> autoSelect() async {
    state = state.copyWith(selecting: true);
    final (server, _) = await SpeedTest().autoSelect();
    state = state.copyWith(server: server, autoSelected: true, selecting: false);
  }

  void choose(SpeedServer s) => state = state.copyWith(server: s, autoSelected: false);

  /// Kilometres from this network's public location to [s], if known.
  double? distanceTo(SpeedServer s) {
    final me = ref.read(networkInfoProvider).value?.geo;
    if (me?.lat == null || s.lat == null) return null;
    return haversineKm(me!.lat!, me.lon!, s.lat!, s.lon!);
  }

  Future<void> start() async {
    if (state.running) return;
    if (!state.hasServer) await autoSelect();
    final started = DateTime.now();
    _test = SpeedTest();
    state = SpeedState(server: state.server, autoSelected: state.autoSelected, phase: SpeedPhase.ping);
    final samples = <SpeedSample>[];
    final done = Completer<void>();
    _sub = _test!
        .run(state.server)
        .listen(
          (u) {
            if (u.sample != null) samples.add(u.sample!);
            state = state.copyWith(
              phase: u.phase,
              liveMbps: u.liveMbps,
              pingMs: u.pingMs,
              jitterMs: u.jitterMs,
              downMbps: u.downMbps,
              upMbps: u.upMbps,
              samples: List.of(samples),
              progress: u.progress,
              colo: u.colo,
            );
          },
          onError: (Object e) {
            state = state.copyWith(phase: SpeedPhase.done, error: 'Speed test failed: $e');
            if (!done.isCompleted) done.complete();
          },
          onDone: () {
            if (!done.isCompleted) done.complete();
          },
        );
    await done.future;
    if (state.phase == SpeedPhase.done && state.error == null && state.downMbps != null) {
      await _save(started);
    } else if (state.phase != SpeedPhase.done) {
      state = state.copyWith(phase: SpeedPhase.idle);
    }
  }

  void cancel() {
    _test?.cancel();
    _sub?.cancel();
    state = state.copyWith(phase: SpeedPhase.idle, liveMbps: 0);
  }

  Future<void> _save(DateTime started) async {
    final s = state;
    final server = s.server.isCloudflare
        ? 'Cloudflare ${s.colo ?? ''}'.trim()
        : '${s.server.name} ${s.server.location}';
    await ref
        .read(historyRepositoryProvider)
        .save(
          tool: SessionTool.speed,
          target: server,
          startedAt: started,
          endedAt: DateTime.now(),
          avgMs: s.pingMs,
          summary: '${s.downMbps!.toStringAsFixed(0)} ↓ · ${s.upMbps?.toStringAsFixed(0) ?? '—'} ↑',
          trend: [for (final x in s.samples.where((x) => !x.upload)) x.mbps].take(12).toList(),
          payload: {
            'down': s.downMbps,
            'up': s.upMbps,
            'ping': s.pingMs,
            'jitter': s.jitterMs,
            'server': s.server.id,
            'colo': s.colo,
          },
        );
  }
}

/// Past speed results, newest first.
final speedHistoryProvider = StreamProvider<List<({DateTime at, double? down, double? up})>>((ref) {
  final db = ref.watch(databaseProvider);
  final q = db.select(db.sessions)
    ..where((s) => s.tool.equals(SessionTool.speed.name))
    ..orderBy([(s) => OrderingTerm.desc(s.startedAt)])
    ..limit(8);
  return q.watch().map(
    (rows) => [
      for (final Session r in rows)
        (
          at: r.startedAt,
          down: (HistoryRepository.payloadOf(r)['down'] as num?)?.toDouble(),
          up: (HistoryRepository.payloadOf(r)['up'] as num?)?.toDouble(),
        ),
    ],
  );
});
