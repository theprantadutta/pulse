@Tags(['render'])
library;

import 'dart:math';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse/core/widgets/wire/wire.dart';
import 'package:pulse/data/db/app_database.dart';
import 'package:pulse/data/models/ping_models.dart';
import 'package:pulse/presentations/screens/history/history_screen.dart';
import 'package:pulse/presentations/screens/ping/ping_configure.dart';
import 'package:pulse/presentations/screens/ping/ping_screen.dart';
import 'package:pulse/providers/database_provider.dart';
import 'package:pulse/providers/ping_provider.dart';
import 'package:pulse/providers/settings_provider.dart';
import 'package:pulse/services/net/ping_prober.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'render_harness.dart';

class _FakeProber implements PingProber {
  final _rand = Random(7);
  @override
  Future<ProbeResult> probe(
    String host, {
    Duration timeout = const Duration(seconds: 2),
    int packetSize = 56,
    int ttl = 64,
    ProbeFamily family = ProbeFamily.auto,
  }) async {
    if (host.endsWith('.99')) return const ProbeResult(status: ProbeStatus.unreachable);
    final base = 8 + host.hashCode % 40;
    final spike = _rand.nextInt(14) == 0 ? 90 : 0;
    if (_rand.nextInt(30) == 0) return const ProbeResult(status: ProbeStatus.timeout);
    return ProbeResult(status: ProbeStatus.ok, rttMs: base + _rand.nextDouble() * 8 + spike, ttl: 117, from: host);
  }
}

const _names = [
  'Personal PC',
  'Office PC',
  'Library PC',
  'Router',
  'NAS',
  'Printer',
  'Game server',
  'Media box',
  'Camera',
  'Laptop',
  'Dead host',
  'Phone',
];

void main() {
  setUpAll(loadWireFonts);

  Future<ProviderContainer> seed() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = AppDatabase(NativeDatabase.memory());
    final c = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        databaseProvider.overrideWithValue(db),
        pingProberProvider.overrideWithValue(_FakeProber()),
        gatewayProvider.overrideWith((ref) async => '192.168.0.1'),
      ],
    );
    for (var i = 0; i < _names.length; i++) {
      await c.read(savedTargetsRepositoryProvider).add(_names[i], i == 10 ? '10.0.0.99' : '10.0.0.${i + 10}');
    }
    return c;
  }

  Widget app(ProviderContainer c, Widget child, Brightness b) => UncontrolledProviderScope(
    container: c,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildWireTheme(b),
      home: Scaffold(body: child),
    ),
  );

  Future<void> runPings(WidgetTester tester, ProviderContainer c) async {
    await tester.runAsync(() async {
      await c.read(pingBoardProvider.notifier).startMany([
        for (var i = 0; i < _names.length; i++) (host: i == 10 ? '10.0.0.99' : '10.0.0.${i + 10}', name: _names[i]),
      ], params: const PingParams(intervalMs: 200, count: 40, timeoutSec: 1));
      await Future<void>.delayed(const Duration(milliseconds: 3000));
      await c.read(pingBoardProvider.notifier).stop(c.read(pingBoardProvider).sessions[3].id);
    });
  }

  for (final b in Brightness.values) {
    testWidgets('ping board + live + configure (${b.name})', (tester) async {
      final c = await tester.runAsync(seed);
      await runPings(tester, c!);

      c.read(pingBoardProvider.notifier).showBoard(true);
      await renderToPng(tester, 'ping_board_desktop_${b.name}', app(c, const PingScreen(), b));
      await renderToPng(
        tester,
        'ping_board_mobile_${b.name}',
        app(c, const PingScreen(), b),
        size: const Size(390, 780),
      );

      c.read(pingBoardProvider.notifier).focus(c.read(pingBoardProvider).sessions[1].id);
      await renderToPng(tester, 'ping_live_desktop_${b.name}', app(c, const PingScreen(), b));
      await renderToPng(
        tester,
        'ping_live_mobile_${b.name}',
        app(c, const PingScreen(), b),
        size: const Size(390, 780),
      );

      c.read(pingBoardProvider.notifier).focus(c.read(pingBoardProvider).sessions[10].id);
      await renderToPng(tester, 'ping_unreachable_desktop_${b.name}', app(c, const PingScreen(), b));

      await tester.runAsync(() async {
        await c.read(pingBoardProvider.notifier).stopAll();
        await Future<void>.delayed(const Duration(milliseconds: 500));
      });
      await renderToPng(tester, 'history_desktop_${b.name}', app(c, const HistoryScreen(), b));
      await renderToPng(
        tester,
        'history_mobile_${b.name}',
        app(c, const HistoryScreen(), b),
        size: const Size(390, 780),
      );
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() async {
        c.dispose();
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump(const Duration(seconds: 1));
    });
  }

  testWidgets('configure with saved targets', (tester) async {
    final c = await tester.runAsync(seed);
    await renderToPng(tester, 'ping_configure_desktop', app(c!, const PingScreen(), Brightness.light));
    await renderToPng(
      tester,
      'ping_start_mobile',
      app(c, const PingScreen(), Brightness.light),
      size: const Size(390, 780),
    );
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() async {
      c.dispose();
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump(const Duration(seconds: 1));
  });
}
