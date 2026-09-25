import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/data/db/app_database.dart';
import 'package:pulse/data/models/ping_models.dart';
import 'package:pulse/providers/database_provider.dart';
import 'package:pulse/providers/ping_provider.dart';
import 'package:pulse/providers/settings_provider.dart';
import 'package:pulse/services/net/ping_prober.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Answers instantly: hosts ending in .9 time out, everything else 20 ms
/// (or 120 ms for .7 to exercise the SLOW threshold).
class _FakeProber implements PingProber {
  @override
  Future<ProbeResult> probe(
    String host, {
    Duration timeout = const Duration(seconds: 2),
    int packetSize = 56,
    int ttl = 64,
    ProbeFamily family = ProbeFamily.auto,
  }) async {
    if (host.endsWith('.9')) return const ProbeResult(status: ProbeStatus.timeout);
    return ProbeResult(
      status: ProbeStatus.ok,
      rttMs: host.endsWith('.7') ? 120 : 20,
      ttl: 64,
      from: host,
    );
  }
}

void main() {
  late ProviderContainer c;
  late AppDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    db = AppDatabase(NativeDatabase.memory());
    c = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        databaseProvider.overrideWithValue(db),
        pingProberProvider.overrideWithValue(_FakeProber()),
      ],
    );
  });

  tearDown(() async {
    c.dispose();
    await db.close();
  });

  Future<void> waitFor(bool Function() done) async {
    for (var i = 0; i < 200 && !done(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
  }

  test('runs 15 named pings at once and saves each to History', () async {
    final board = c.read(pingBoardProvider.notifier);
    const params = PingParams(count: 4, intervalMs: 200, timeoutSec: 1);
    final started = await board.startMany([
      for (var i = 1; i <= 15; i++) (host: '10.0.0.$i', name: 'PC $i'),
    ], params: params);
    expect(started, 15);
    expect(c.read(pingBoardProvider).liveCount, 15);
    expect(c.read(pingBoardProvider).showBoard, isTrue);

    await waitFor(() => c.read(pingBoardProvider).liveCount == 0);
    final sessions = c.read(pingBoardProvider).sessions;
    expect(sessions, hasLength(15));
    for (final s in sessions) {
      expect(s.running, isFalse);
      expect(s.stats.sent, 4);
    }
    final pc9 = sessions.firstWhere((s) => s.name == 'PC 9');
    expect(pc9.stats.lossPct, 100);
    final pc7 = sessions.firstWhere((s) => s.name == 'PC 7');
    expect(pc7.replies.every((r) => r.state == ReplyState.slow), isTrue);

    await waitFor(() => c.read(pingBoardProvider).sessions.every((s) => s.historyId != null));
    final rows = await db.select(db.sessions).get();
    expect(rows, hasLength(15));
    expect(rows.map((r) => r.label), contains('PC 3'));

    final found = await c.read(historyRepositoryProvider).watch(search: 'pc 12').first;
    expect(found.single.target, '10.0.0.12');
  });

  test('saved target names are applied automatically and STOP ALL works', () async {
    await c.read(savedTargetsRepositoryProvider).add('Office PC', '10.1.1.2');
    final board = c.read(pingBoardProvider.notifier);
    final id = await board.start('10.1.1.2', params: const PingParams(intervalMs: 200));
    expect(c.read(pingBoardProvider).sessions.single.name, 'Office PC');
    await board.start('10.1.1.3', name: 'Library PC', params: const PingParams(intervalMs: 200));
    expect(c.read(pingBoardProvider).liveCount, 2);
    await board.stopAll();
    expect(c.read(pingBoardProvider).liveCount, 0);
    await board.remove(id!);
    expect(c.read(pingBoardProvider).sessions.single.name, 'Library PC');
  });

  test('concurrent limit is enforced', () async {
    final board = c.read(pingBoardProvider.notifier);
    final n = await board.startMany([
      for (var i = 0; i < kMaxLivePings + 5; i++) (host: '10.2.0.$i', name: null),
    ], params: const PingParams(intervalMs: 2000));
    expect(n, kMaxLivePings);
    await board.stopAll();
  });
}
