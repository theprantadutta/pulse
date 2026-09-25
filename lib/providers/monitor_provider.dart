import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../core/constants/shared_preference_keys.dart';
import '../data/db/app_database.dart';
import '../services/background/background_service.dart';
import '../services/background/monitor_engine.dart';
import '../services/desktop/desktop_host.dart';
import 'database_provider.dart';
import 'ping_provider.dart';
import 'settings_provider.dart';

/// Where monitoring currently runs.
enum MonitorMode { idle, app, tray, service, paused }

@immutable
class MonitorRunState {
  const MonitorRunState({this.mode = MonitorMode.idle, this.last, this.cycling = false});
  final MonitorMode mode;
  final CycleReport? last;
  final bool cycling;

  bool get live => mode == MonitorMode.app || mode == MonitorMode.tray || mode == MonitorMode.service;

  String get label => switch (mode) {
    MonitorMode.tray => 'RUNNING IN TRAY',
    MonitorMode.service => 'RUNNING IN BACKGROUND',
    MonitorMode.app => 'RUNNING WHILE OPEN',
    MonitorMode.paused => 'PAUSED',
    MonitorMode.idle => 'IDLE',
  };
}

final monitorEngineProvider = Provider<MonitorEngine>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return MonitorEngine(
    db: ref.watch(databaseProvider),
    prober: ref.watch(pingProberProvider),
    settings: () => ref.read(settingsProvider),
    mutedUntil: () {
      final ms = prefs.getInt(kAlertsMutedUntilKey);
      return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
    },
    onTrayAlert: (message) {
      if (DesktopHost.supported) {
        DesktopHost.instance.setStatus(message, alert: true, paused: false);
      }
    },
  );
});

final monitorRunnerProvider = NotifierProvider<MonitorRunner, MonitorRunState>(MonitorRunner.new);

class MonitorRunner extends Notifier<MonitorRunState> {
  Timer? _timer;
  int _interval = 0;
  bool _started = false;
  StreamSubscription<int>? _targetsSub;
  int _targets = 0;

  bool get _paused => ref.read(sharedPreferencesProvider).getBool(kMonitorPausedKey) ?? false;

  @override
  MonitorRunState build() {
    ref.onDispose(() {
      _timer?.cancel();
      _targetsSub?.cancel();
      FlutterForegroundTask.removeTaskDataCallback(_onServiceData);
    });
    ref.listen(settingsProvider.select((s) => (s.monitorIntervalSec, s.monitorInBackground)), (_, _) {
      if (_started) _configure();
    });
    return const MonitorRunState();
  }

  /// Called once at boot.
  Future<void> start() async {
    if (_started) return;
    _started = true;
    if (BackgroundMonitor.supported) {
      BackgroundMonitor.init(intervalSec: ref.read(settingsProvider).monitorIntervalSec);
      FlutterForegroundTask.addTaskDataCallback(_onServiceData);
    }
    final db = ref.read(databaseProvider);
    final count = db.monitorTargets.id.count();
    final q = db.selectOnly(db.monitorTargets)
      ..addColumns([count])
      ..where(db.monitorTargets.enabled.equals(true));
    _targetsSub = q.watchSingle().map((r) => r.read(count) ?? 0).listen((n) {
      final changed = n != _targets;
      _targets = n;
      if (changed) _configure();
    });
  }

  void _onServiceData(Object data) {
    if (data is! Map) return;
    state = MonitorRunState(
      mode: MonitorMode.service,
      last: CycleReport(
        targets: data['targets'] as int? ?? 0,
        down: data['down'] as int? ?? 0,
        firing: data['firing'] as int? ?? 0,
        at: DateTime.fromMillisecondsSinceEpoch(data['at'] as int? ?? 0),
      ),
    );
  }

  Future<void> setPaused(bool paused) async {
    await ref.read(sharedPreferencesProvider).setBool(kMonitorPausedKey, paused);
    await _configure();
  }

  Future<void> togglePaused() => setPaused(!_paused);

  Future<void> _configure() async {
    final settings = ref.read(settingsProvider);
    final newDeviceRules = await (ref.read(databaseProvider).select(ref.read(databaseProvider).alertRules)
          ..where((r) => r.enabled.equals(true) & r.metric.equals(AlertMetric.newDevice)))
        .get();
    final work = _targets > 0 || newDeviceRules.isNotEmpty || settings.lanDeviceWatch;

    if (_paused || !work) {
      _stopTimer();
      await BackgroundMonitor.stop();
      state = MonitorRunState(mode: _paused ? MonitorMode.paused : MonitorMode.idle, last: state.last);
      _pushDesktopStatus();
      return;
    }

    if (BackgroundMonitor.supported && settings.monitorInBackground) {
      _stopTimer();
      final running = await BackgroundMonitor.isRunning;
      if (!running || _interval != settings.monitorIntervalSec) {
        _interval = settings.monitorIntervalSec;
        await BackgroundMonitor.start(
          intervalSec: settings.monitorIntervalSec,
          summary: '$_targets target${_targets == 1 ? '' : 's'}',
        );
      }
      state = MonitorRunState(mode: MonitorMode.service, last: state.last);
      return;
    }

    await BackgroundMonitor.stop();
    if (_timer == null || _interval != settings.monitorIntervalSec) {
      _stopTimer();
      _interval = settings.monitorIntervalSec;
      _timer = Timer.periodic(Duration(seconds: _interval), (_) => runNow());
      unawaited(runNow());
    }
    state = MonitorRunState(mode: DesktopHost.supported ? MonitorMode.tray : MonitorMode.app, last: state.last);
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  /// Runs one cycle in this isolate (also the "check now" action).
  Future<void> runNow() async {
    if (state.cycling) return;
    if (state.mode == MonitorMode.service) {
      // The service owns the cycles; ask it to refresh its notification.
      return;
    }
    state = MonitorRunState(mode: state.mode, last: state.last, cycling: true);
    try {
      final engine = ref.read(monitorEngineProvider);
      final report = await engine.runCycle();
      if (!Platform.isIOS) await engine.runLanWatch();
      state = MonitorRunState(mode: state.mode, last: report);
    } on Object catch (e) {
      debugPrint('Monitor cycle failed: $e');
      state = MonitorRunState(mode: state.mode, last: state.last);
    }
    _pushDesktopStatus();
  }

  void _pushDesktopStatus() {
    if (!DesktopHost.supported) return;
    final r = state.last;
    DesktopHost.instance.setStatus(
      state.mode == MonitorMode.paused ? 'monitoring paused' : r?.summary ?? 'monitoring',
      alert: (r?.firing ?? 0) > 0,
      paused: state.mode == MonitorMode.paused,
    );
  }
}

// ------------------------------------------------------------------- data

enum MonitorRange { day, week, month }

extension MonitorRangeX on MonitorRange {
  Duration get span => switch (this) {
    MonitorRange.day => const Duration(hours: 24),
    MonitorRange.week => const Duration(days: 7),
    MonitorRange.month => const Duration(days: 30),
  };

  String get label => switch (this) {
    MonitorRange.day => '24H',
    MonitorRange.week => '7D',
    MonitorRange.month => '30D',
  };

  /// 48 blocks across the range.
  Duration get block => Duration(seconds: span.inSeconds ~/ 48);

  String get blockLabel => switch (this) {
    MonitorRange.day => '30 MIN BLOCKS',
    MonitorRange.week => '3.5 HR BLOCKS',
    MonitorRange.month => '15 HR BLOCKS',
  };
}

final monitorRangeProvider = NotifierProvider<MonitorRangeNotifier, MonitorRange>(MonitorRangeNotifier.new);

class MonitorRangeNotifier extends Notifier<MonitorRange> {
  @override
  MonitorRange build() => MonitorRange.day;
  void set(MonitorRange r) => state = r;
}

enum BlockState { empty, healthy, degraded, down }

@immutable
class TargetRow {
  const TargetRow({
    required this.target,
    required this.blocks,
    required this.uptime,
    this.nowMs,
    this.nowDown = false,
    this.incident = false,
  });

  final MonitorTarget target;
  final List<BlockState> blocks;
  final double? uptime;
  final double? nowMs;
  final bool nowDown;

  /// Has an ongoing incident.
  final bool incident;
}

@immutable
class MonitorOverview {
  const MonitorOverview({
    required this.rows,
    required this.uptime,
    required this.avgMs,
    required this.incidents,
    required this.checks,
  });

  final List<TargetRow> rows;
  final double? uptime;
  final double? avgMs;
  final int incidents;
  final int checks;
}

/// Everything the Monitor screen shows, recomputed whenever checks,
/// incidents or targets change.
final monitorOverviewProvider = StreamProvider<MonitorOverview>((ref) {
  final db = ref.watch(databaseProvider);
  final range = ref.watch(monitorRangeProvider);
  final trigger = db.customSelect(
    'SELECT (SELECT MAX(id) FROM monitor_checks) AS c, (SELECT COUNT(*) FROM monitor_targets) AS t, '
    '(SELECT COUNT(*) FROM incidents WHERE ended_at IS NULL) AS i',
    readsFrom: {db.monitorChecks, db.monitorTargets, db.incidents},
  ).watchSingle();
  return trigger.asyncMap((_) => _overview(db, range));
});

Future<MonitorOverview> _overview(AppDatabase db, MonitorRange range) async {
  final now = DateTime.now();
  final start = now.subtract(range.span);
  final blockSec = range.block.inSeconds;
  final startSec = start.millisecondsSinceEpoch ~/ 1000;
  final targets = await (db.select(db.monitorTargets)..orderBy([(t) => OrderingTerm.asc(t.sortOrder), (t) => OrderingTerm.asc(t.id)])).get();

  // drift stores DateTime as unix seconds.
  final rows = await db.customSelect(
    'SELECT target_id, CAST((at - ?) / ? AS INTEGER) AS b, COUNT(*) AS n, '
    'SUM(CASE WHEN received = 0 THEN 1 ELSE 0 END) AS down, SUM(sent) AS sent, SUM(received) AS recv, AVG(rtt_avg) AS rtt '
    'FROM monitor_checks WHERE at >= ? GROUP BY target_id, b',
    variables: [Variable.withInt(startSec), Variable.withInt(blockSec), Variable.withInt(startSec)],
    readsFrom: {db.monitorChecks},
  ).get();

  final open = await (db.select(db.incidents)..where((i) => i.endedAt.isNull())).get();
  final openTargets = open.map((i) => i.targetId).toSet();
  final incidentsInRange = await (db.select(db.incidents)..where((i) => i.startedAt.isBiggerOrEqualValue(start))).get();

  final byTarget = <int, Map<int, QueryRow>>{};
  for (final r in rows) {
    byTarget.putIfAbsent(r.read<int>('target_id'), () => {})[r.read<int>('b')] = r;
  }

  var totalChecks = 0, totalUp = 0;
  double rttSum = 0;
  var rttN = 0;
  final out = <TargetRow>[];
  for (final t in targets) {
    final buckets = byTarget[t.id] ?? const {};
    // The target's normal latency over the range, to spot degraded blocks.
    final rtts = [for (final r in buckets.values) r.readNullable<double>('rtt')].whereType<double>().toList()..sort();
    final normal = rtts.isEmpty ? null : rtts[rtts.length ~/ 2];
    var checks = 0, up = 0;
    final blocks = <BlockState>[];
    for (var b = 0; b < 48; b++) {
      final r = buckets[b];
      if (r == null) {
        blocks.add(BlockState.empty);
        continue;
      }
      final n = r.read<int>('n');
      final down = r.read<int>('down');
      final sent = r.read<int>('sent');
      final recv = r.read<int>('recv');
      final rtt = r.readNullable<double>('rtt');
      checks += n;
      up += n - down;
      if (rtt != null) {
        rttSum += rtt * (n - down);
        rttN += n - down;
      }
      final loss = sent == 0 ? 0 : (sent - recv) / sent;
      if (down / n >= 0.5) {
        blocks.add(BlockState.down);
      } else if (down > 0 || loss > 0.05 || (normal != null && rtt != null && rtt > normal * 2 + 20)) {
        blocks.add(BlockState.degraded);
      } else {
        blocks.add(BlockState.healthy);
      }
    }
    totalChecks += checks;
    totalUp += up;
    final last = await (db.select(db.monitorChecks)
          ..where((c) => c.targetId.equals(t.id))
          ..orderBy([(c) => OrderingTerm.desc(c.at)])
          ..limit(1))
        .getSingleOrNull();
    out.add(
      TargetRow(
        target: t,
        blocks: blocks,
        uptime: checks == 0 ? null : up / checks * 100,
        nowMs: last?.rttAvg,
        nowDown: last != null && last.received == 0,
        incident: openTargets.contains(t.id),
      ),
    );
  }
  return MonitorOverview(
    rows: out,
    uptime: totalChecks == 0 ? null : totalUp / totalChecks * 100,
    avgMs: rttN == 0 ? null : rttSum / rttN,
    incidents: incidentsInRange.length,
    checks: totalChecks,
  );
}

@immutable
class IncidentView {
  const IncidentView(this.incident, this.targetName);
  final Incident incident;
  final String targetName;
  bool get ongoing => incident.endedAt == null;
}

final incidentsProvider = StreamProvider<List<IncidentView>>((ref) {
  final db = ref.watch(databaseProvider);
  final q = db.select(db.incidents).join([
    innerJoin(db.monitorTargets, db.monitorTargets.id.equalsExp(db.incidents.targetId)),
  ])
    ..orderBy([OrderingTerm.desc(db.incidents.startedAt)])
    ..limit(40);
  return q.watch().map((rows) {
    final list = [
      for (final r in rows)
        IncidentView(r.readTable(db.incidents), r.readTable(db.monitorTargets).name),
    ];
    list.sort((a, b) {
      if (a.ongoing != b.ongoing) return a.ongoing ? -1 : 1;
      return b.incident.startedAt.compareTo(a.incident.startedAt);
    });
    return list;
  });
});

/// Target CRUD.
class MonitorTargetsRepository {
  MonitorTargetsRepository(this.db);
  final AppDatabase db;

  Future<int> add(String host, String name) async {
    final existing = await (db.select(db.monitorTargets)..where((t) => t.host.lower().equals(host.toLowerCase()))).getSingleOrNull();
    if (existing != null) {
      await (db.update(db.monitorTargets)..where((t) => t.id.equals(existing.id)))
          .write(MonitorTargetsCompanion(enabled: const Value(true), name: Value(name.isEmpty ? existing.name : name)));
      return existing.id;
    }
    final n = await db.monitorTargets.count().getSingle();
    return db.into(db.monitorTargets).insert(
      MonitorTargetsCompanion.insert(host: host.trim(), name: name.trim(), sortOrder: Value(n), createdAt: DateTime.now()),
    );
  }

  Future<void> update(int id, {String? name, bool? enabled}) =>
      (db.update(db.monitorTargets)..where((t) => t.id.equals(id))).write(
        MonitorTargetsCompanion(
          name: name == null ? const Value.absent() : Value(name),
          enabled: enabled == null ? const Value.absent() : Value(enabled),
        ),
      );

  Future<void> delete(int id) => (db.delete(db.monitorTargets)..where((t) => t.id.equals(id))).go();
}

final monitorTargetsRepositoryProvider = Provider<MonitorTargetsRepository>(
  (ref) => MonitorTargetsRepository(ref.watch(databaseProvider)),
);
