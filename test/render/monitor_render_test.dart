@Tags(['render'])
library;

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse/core/widgets/wire/wire.dart';
import 'package:pulse/data/db/app_database.dart';
import 'package:pulse/data/models/app_settings.dart';
import 'package:pulse/presentations/screens/alerts/alerts_screen.dart';
import 'package:pulse/presentations/screens/monitor/monitor_screen.dart';
import 'package:pulse/providers/database_provider.dart';
import 'package:pulse/providers/settings_provider.dart';
import 'package:pulse/services/background/monitor_engine.dart';
import 'package:pulse/services/net/ping_prober.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'render_harness.dart';

class _Net implements PingProber {
  bool discordDown = false;
  final _n = <String, int>{};
  @override
  Future<ProbeResult> probe(
    String host, {
    Duration timeout = const Duration(seconds: 2),
    int packetSize = 56,
    int ttl = 64,
    ProbeFamily family = ProbeFamily.auto,
  }) async {
    final i = _n[host] = (_n[host] ?? 0) + 1;
    return switch (host) {
      '192.168.1.1' => const ProbeResult(status: ProbeStatus.ok, rttMs: 2),
      '8.8.8.8' => ProbeResult(status: ProbeStatus.ok, rttMs: 24 + (i % 5).toDouble()),
      'discord.gg' =>
        discordDown
            ? const ProbeResult(status: ProbeStatus.timeout)
            : i % 4 == 0
            ? const ProbeResult(status: ProbeStatus.timeout)
            : const ProbeResult(status: ProbeStatus.ok, rttMs: 87),
      _ => const ProbeResult(status: ProbeStatus.ok, rttMs: 42),
    };
  }
}

void main() {
  setUpAll(loadWireFonts);

  Future<(AppDatabase, SharedPreferences)> seed(WidgetTester tester) async {
    final r = await tester.runAsync(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final db = AppDatabase(NativeDatabase.memory());
      final now = DateTime.now();
      for (final (h, n) in [
        ('192.168.1.1', 'Router'),
        ('8.8.8.8', 'Google DNS'),
        ('1.1.1.1', 'Cloudflare'),
        ('github.com', 'GitHub'),
        ('discord.gg', 'Discord'),
      ]) {
        await db.into(db.monitorTargets).insert(MonitorTargetsCompanion.insert(host: h, name: n, createdAt: now));
      }
      await db
          .into(db.alertRules)
          .insert(
            AlertRulesCompanion.insert(
              title: 'High latency',
              target: '8.8.8.8',
              metric: AlertMetric.latency,
              threshold: const Value(100),
              createdAt: now,
              channels: const Value(3),
            ),
          );
      await db
          .into(db.alertRules)
          .insert(
            AlertRulesCompanion.insert(
              title: 'Packet loss',
              target: '*',
              metric: AlertMetric.loss,
              threshold: const Value(5),
              forSeconds: const Value(0),
              createdAt: now,
            ),
          );
      await db
          .into(db.alertRules)
          .insert(
            AlertRulesCompanion.insert(
              title: 'Gateway down',
              target: '192.168.1.1',
              metric: AlertMetric.down,
              forSeconds: const Value(10),
              createdAt: now,
              channels: const Value(5),
            ),
          );
      await db
          .into(db.alertRules)
          .insert(
            AlertRulesCompanion.insert(
              title: 'New LAN device',
              target: '*',
              metric: AlertMetric.newDevice,
              enabled: const Value(false),
              createdAt: now,
              channels: const Value(2),
            ),
          );
      final net = _Net();
      final engine = MonitorEngine(
        db: db,
        prober: net,
        settings: () => const AppSettings(notificationsEnabled: false, monitorIntervalSec: 60),
      );
      for (var i = 0; i < 6; i++) {
        await engine.runCycle();
      }
      net.discordDown = true;
      await engine.runCycle();
      return (db, prefs);
    });
    return r!;
  }

  Widget app(AppDatabase db, SharedPreferences prefs, Widget child, Brightness b) => ProviderScope(
    overrides: [databaseProvider.overrideWithValue(db), sharedPreferencesProvider.overrideWithValue(prefs)],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildWireTheme(b),
      home: Scaffold(body: child),
    ),
  );

  testWidgets('monitor + alerts', (tester) async {
    final (db, prefs) = await seed(tester);
    Future<void> shot(String name, Widget child, Brightness b, Size size) async {
      await renderToPng(tester, name, app(db, prefs, child, b), size: size);
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
      await tester.pump(const Duration(milliseconds: 100));
      await renderToPng(tester, name, app(db, prefs, child, b), size: size);
    }

    await shot('monitor_desktop_light', const MonitorScreen(), Brightness.light, const Size(1060, 736));
    await shot('monitor_mobile_light', const MonitorScreen(), Brightness.light, const Size(390, 780));
    await shot('alerts_desktop_light', const AlertsScreen(), Brightness.light, const Size(1060, 736));
    await shot('alerts_mobile_dark', const AlertsScreen(), Brightness.dark, const Size(390, 780));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
