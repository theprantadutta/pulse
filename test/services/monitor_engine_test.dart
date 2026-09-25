import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/data/db/app_database.dart';
import 'package:pulse/data/models/app_settings.dart';
import 'package:pulse/services/background/monitor_engine.dart';
import 'package:pulse/services/net/ping_prober.dart';

/// Scripted network: per host, what every probe returns right now.
class _Net implements PingProber {
  final state = <String, ProbeResult Function(int i)>{};
  final _n = <String, int>{};

  @override
  Future<ProbeResult> probe(
    String host, {
    Duration timeout = const Duration(seconds: 2),
    int packetSize = 56,
    int ttl = 64,
    ProbeFamily family = ProbeFamily.auto,
  }) async {
    final i = _n[host] = (_n[host] ?? -1) + 1;
    return (state[host] ?? (_) => const ProbeResult(status: ProbeStatus.ok, rttMs: 20))(i);
  }
}

void main() {
  late AppDatabase db;
  late _Net net;
  late MonitorEngine engine;
  final tray = <String>[];

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    net = _Net();
    tray.clear();
    engine = MonitorEngine(
      db: db,
      prober: net,
      // Push off so the test does not need the notifications plugin.
      settings: () => const AppSettings(notificationsEnabled: false, monitorIntervalSec: 1),
      onTrayAlert: tray.add,
    );
    final now = DateTime.now();
    await db.into(db.monitorTargets).insert(MonitorTargetsCompanion.insert(host: '10.0.0.1', name: 'Router', createdAt: now));
    await db.into(db.monitorTargets).insert(MonitorTargetsCompanion.insert(host: 'game.example', name: 'Game', createdAt: now));
  });

  tearDown(() => db.close());

  Future<void> cycles(int n) async {
    for (var i = 0; i < n; i++) {
      await engine.runCycle();
    }
  }

  test('healthy targets produce checks and no incidents', () async {
    final r = await engine.runCycle();
    expect(r.targets, 2);
    expect(r.down, 0);
    expect(await db.select(db.monitorChecks).get(), hasLength(2));
    expect(await db.select(db.incidents).get(), isEmpty);
  });

  test('a down host opens and later closes a DOWN incident', () async {
    net.state['10.0.0.1'] = (_) => const ProbeResult(status: ProbeStatus.timeout);
    await cycles(2);
    var open = await (db.select(db.incidents)..where((i) => i.endedAt.isNull())).get();
    expect(open.single.kind, 'down');
    expect(open.single.title, 'Router unreachable');
    net.state.remove('10.0.0.1');
    await engine.runCycle();
    open = await (db.select(db.incidents)..where((i) => i.endedAt.isNull())).get();
    expect(open, isEmpty);
  });

  test('sustained loss opens a LOSS incident', () async {
    // One probe in three is lost → 33% loss, but every check gets replies.
    net.state['game.example'] = (i) => i % 3 == 0
        ? const ProbeResult(status: ProbeStatus.timeout)
        : const ProbeResult(status: ProbeStatus.ok, rttMs: 30);
    await cycles(4);
    final incidents = await db.select(db.incidents).get();
    expect(incidents.where((i) => i.kind == 'loss'), hasLength(1));
  });

  test('down rule fires once after its hold time and resets on recovery', () async {
    await db.into(db.alertRules).insert(
      AlertRulesCompanion.insert(
        title: 'Gateway down',
        target: '10.0.0.1',
        metric: AlertMetric.down,
        forSeconds: const Value(0),
        channels: const Value(AlertChannel.push | AlertChannel.tray),
        createdAt: DateTime.now(),
      ),
    );
    net.state['10.0.0.1'] = (_) => const ProbeResult(status: ProbeStatus.timeout);
    await cycles(3);
    final events = await db.select(db.alertEvents).get();
    expect(events, hasLength(1), reason: 'fires once per breach, not every cycle');
    expect(events.single.message, startsWith('10.0.0.1 unreachable'));
    expect(tray, hasLength(1));
    var rule = await db.select(db.alertRules).getSingle();
    expect(rule.firing, isTrue);

    net.state.remove('10.0.0.1');
    await engine.runCycle();
    rule = await db.select(db.alertRules).getSingle();
    expect(rule.firing, isFalse);
    expect(rule.breachSince, isNull);
  });

  test('latency rule on any target (*) respects the threshold', () async {
    await db.into(db.alertRules).insert(
      AlertRulesCompanion.insert(
        title: 'High latency',
        target: '*',
        metric: AlertMetric.latency,
        threshold: const Value(100),
        forSeconds: const Value(0),
        createdAt: DateTime.now(),
      ),
    );
    await engine.runCycle();
    expect(await db.select(db.alertEvents).get(), isEmpty);
    net.state['game.example'] = (_) => const ProbeResult(status: ProbeStatus.ok, rttMs: 180);
    await engine.runCycle();
    final e = await db.select(db.alertEvents).getSingle();
    expect(e.message, 'game.example RTT 180 ms (> 100)');
  });

  test('muted alerts are logged but not delivered', () async {
    engine = MonitorEngine(
      db: db,
      prober: net,
      settings: () => const AppSettings(notificationsEnabled: false, monitorIntervalSec: 1),
      onTrayAlert: tray.add,
      mutedUntil: () => DateTime.now().add(const Duration(hours: 1)),
    );
    await db.into(db.alertRules).insert(
      AlertRulesCompanion.insert(
        title: 'Down',
        target: '*',
        metric: AlertMetric.down,
        forSeconds: const Value(0),
        channels: const Value(AlertChannel.tray),
        createdAt: DateTime.now(),
      ),
    );
    net.state['10.0.0.1'] = (_) => const ProbeResult(status: ProbeStatus.timeout);
    await engine.runCycle();
    expect(await db.select(db.alertEvents).get(), hasLength(1));
    expect(tray, isEmpty);
  });
}
