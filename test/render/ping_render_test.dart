@Tags(['render'])
library;

import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:drift/native.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse/core/theme/pulse_theme.dart';
import 'package:pulse/data/db/app_database.dart';
import 'package:pulse/data/models/ping_models.dart';
import 'package:pulse/presentations/navigation/pulse_shell.dart';
import 'package:pulse/presentations/screens/ping/ping_configure.dart';
import 'package:pulse/presentations/screens/ping/ping_detail_screen.dart';
import 'package:pulse/presentations/screens/ping/ping_screen.dart';
import 'package:pulse/providers/connection_provider.dart';
import 'package:pulse/providers/database_provider.dart';
import 'package:pulse/providers/ping_provider.dart';
import 'package:pulse/providers/settings_provider.dart';
import 'package:pulse/services/net/ping_prober.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'render_harness.dart';

/// Kit-like hosts (IP literals so no real DNS runs): base RTT and loss rate.
const _hosts = <({String name, String host, double base, double spread, int lossEvery})>[
  (name: 'Router', host: '192.168.0.1', base: 4.2, spread: 2, lossEvery: 0),
  (name: 'Google DNS', host: '8.8.8.8', base: 33, spread: 6, lossEvery: 0),
  (name: 'Cloudflare', host: '1.1.1.1', base: 7, spread: 5, lossEvery: 0),
  (name: 'GitHub', host: '140.82.121.4', base: 52, spread: 10, lossEvery: 22),
  (name: 'Cloudflare Web', host: '104.16.132.229', base: 11, spread: 8, lossEvery: 40),
  (name: 'Google', host: '142.250.183.14', base: 42, spread: 9, lossEvery: 18),
];

class _FakeProber implements PingProber {
  final _rand = Random(7);
  final _n = <String, int>{};

  @override
  Future<ProbeResult> probe(
    String host, {
    Duration timeout = const Duration(seconds: 2),
    int packetSize = 56,
    int ttl = 64,
    ProbeFamily family = ProbeFamily.auto,
  }) async {
    if (host == '10.0.0.99') return const ProbeResult(status: ProbeStatus.timeout);
    final h = _hosts.firstWhere((x) => x.host == host, orElse: () => _hosts[1]);
    final n = _n[host] = (_n[host] ?? 0) + 1;
    if (h.lossEvery > 0 && n % h.lossEvery == 5) return const ProbeResult(status: ProbeStatus.timeout);
    final spike = _rand.nextInt(25) == 0 ? 50.0 : 0.0;
    return ProbeResult(
      status: ProbeStatus.ok,
      rttMs: h.base + _rand.nextDouble() * h.spread + spike,
      ttl: 117,
      from: host,
    );
  }
}

void main() {
  setUpAll(loadPulseFonts);

  Future<ProviderContainer> seed() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = AppDatabase(NativeDatabase.memory());
    return ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        databaseProvider.overrideWithValue(db),
        pingProberProvider.overrideWithValue(_FakeProber()),
        gatewayProvider.overrideWith((ref) async => '192.168.0.1'),
        connectionProvider.overrideWith((ref) => const Stream.empty()),
      ],
    );
  }

  /// Six hosts pinging every 100 ms for ~6.5 s (60+ samples each).
  Future<void> runPings(WidgetTester tester, ProviderContainer c, {bool dead = false}) async {
    await tester.runAsync(() async {
      await c.read(gatewayProvider.future);
      await c.read(pingBoardProvider.notifier).startMany([
        for (final h in _hosts) (host: h.host, name: h.name),
        if (dead) (host: '10.0.0.99', name: 'Office PC'),
      ], params: const PingParams(intervalMs: 100, timeoutSec: 1));
      await Future<void>.delayed(const Duration(milliseconds: 6500));
    });
    final sessions = c.read(pingBoardProvider).sessions;
    c.read(pingBoardProvider.notifier).focus(sessions[1].id);
  }

  Future<void> teardown(WidgetTester tester, ProviderContainer c) async {
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() async {
      await c.read(pingBoardProvider.notifier).stopAll();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      c.dispose();
    });
    await tester.pump(const Duration(seconds: 1));
  }

  /// Writes what is on screen now (including open sheets) to a PNG.
  Future<void> capture(WidgetTester tester, String name) async {
    await tester.pump(const Duration(milliseconds: 400));
    await tester.runAsync(() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(find.byType(RepaintBoundary).first);
      final image = await boundary.toImage();
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      File('build/renders/$name.png')
        ..createSync(recursive: true)
        ..writeAsBytesSync(data!.buffer.asUint8List());
    });
  }

  testWidgets('ping home + detail', (tester) async {
    final c = (await tester.runAsync(seed))!;
    await runPings(tester, c);
    final id = c.read(pingBoardProvider).sessions[1].id;
    final failures = [
      ...await renderMatrix(tester, 'ping', c, const PingScreen()),
      ...await renderMatrix(
        tester,
        'ping_detail',
        c,
        PingDetailScreen(id: id),
        location: '/ping/host',
        devices: const {'phone': kPhone, 'tablet': kTablet, 'medium': Size(720, 1000)},
      ),
      ...await renderMatrix(
        tester,
        'ping',
        c,
        const PingScreen(),
        devices: const {'medium': Size(720, 1000), 'narrow': Size(360, 760)},
      ),
    ];

    // Sheets: add host, ping settings, per-host options.
    await renderToPng(tester, 'ping_sheet_base', pulseTestApp(c, const PingScreen()), size: kPhone);
    await tester.ensureVisible(find.text('Add host').first);
    await tester.pump();
    await tester.tap(find.text('Add host').first);
    await tester.pump();
    expect(find.text('Quick targets'), findsOneWidget);
    await capture(tester, 'ping_sheet_add_phone_dark');
    await renderToPng(tester, 'ping_sheet_base', pulseTestApp(c, const PingScreen()), size: kPhone);
    await tester.tap(find.byTooltip('Ping settings'));
    await tester.pump();
    expect(find.text('Used for every host you add'), findsOneWidget);
    await capture(tester, 'ping_sheet_settings_phone_dark');
    await renderToPng(
      tester,
      'ping_sheet_base',
      pulseTestApp(
        c,
        PingDetailScreen(id: id),
        location: '/ping/host',
        brightness: Brightness.light,
      ),
      size: kPhone,
    );
    await tester.tap(find.text('Timeout 1 s'));
    await capture(tester, 'ping_sheet_timeout_phone_light');

    await teardown(tester, c);
    expect(failures, isEmpty);
  });

  testWidgets('ping states: down, paused, empty, large text', (tester) async {
    final c = (await tester.runAsync(seed))!;
    final failures = <String>[];
    failures.addAll(await renderMatrix(tester, 'ping_empty', c, const PingScreen()));

    await runPings(tester, c, dead: true);
    final dead = c.read(pingBoardProvider).sessions.last;
    c.read(pingBoardProvider.notifier).focus(dead.id);
    const phone = {'phone': kPhone};
    failures
      ..addAll(await renderMatrix(tester, 'ping_down', c, const PingScreen(), devices: phone))
      ..addAll(
        await renderMatrix(tester, 'ping_detail_down', c, PingDetailScreen(id: dead.id), location: '/ping/host'),
      );

    await tester.runAsync(() async {
      await c.read(pingBoardProvider.notifier).stopAll();
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    final first = c.read(pingBoardProvider).sessions[1];
    c.read(pingBoardProvider.notifier).focus(first.id);
    failures
      ..addAll(await renderMatrix(tester, 'ping_paused', c, const PingScreen()))
      ..addAll(
        await renderMatrix(
          tester,
          'ping_detail_paused',
          c,
          PingDetailScreen(id: first.id),
          location: '/ping/host',
          devices: phone,
        ),
      );

    // 1.3x text at 360 dp: no overflow.
    for (final entry in <String, Widget>{
      'ping_big': const PingScreen(),
      'ping_detail_big': PingDetailScreen(id: first.id),
    }.entries) {
      await renderToPng(
        tester,
        entry.key,
        UncontrolledProviderScope(
          container: c,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: buildPulseTheme(Brightness.dark),
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(360, 760),
                padding: EdgeInsets.only(top: 40, bottom: 20),
                textScaler: TextScaler.linear(1.3),
                disableAnimations: true,
              ),
              child: PulseShell(location: entry.value is PingScreen ? '/ping' : '/ping/host', child: entry.value),
            ),
          ),
        ),
        size: const Size(360, 760),
      );
      final e = tester.takeException();
      if (e != null) failures.add('${entry.key}: $e');
    }

    await teardown(tester, c);
    expect(failures, isEmpty);
  });
}
