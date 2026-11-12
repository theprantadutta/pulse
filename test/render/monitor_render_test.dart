@Tags(['render'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse/core/theme/pulse_theme.dart';
import 'package:pulse/data/db/app_database.dart';
import 'package:pulse/presentations/navigation/pulse_shell.dart';
import 'package:pulse/presentations/screens/alerts/alerts_screen.dart';
import 'package:pulse/presentations/screens/monitor/monitor_screen.dart';
import 'package:pulse/providers/database_provider.dart';
import 'package:pulse/providers/monitor_provider.dart';
import 'package:pulse/providers/settings_provider.dart';
import 'package:pulse/services/background/monitor_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'render_harness.dart';

/// Monitoring "running while open" with a recent cycle, without timers.
class _Runner extends MonitorRunner {
  _Runner(this.mode);
  final MonitorMode mode;

  @override
  MonitorRunState build() => MonitorRunState(
    mode: mode,
    last: CycleReport(targets: 6, down: 0, firing: 0, at: DateTime.now().subtract(const Duration(seconds: 40))),
  );

  @override
  Future<void> togglePaused() async {}
}

const _targets = [
  ('1.1.1.1', 'Cloudflare', 13.0),
  ('8.8.8.8', 'Google DNS', 58.0),
  ('github.com', 'GitHub', 65.0),
  ('192.168.0.1', 'Router', 1.8),
  ('aws.amazon.com', 'AWS', 18.0),
  ('google.com', 'Google', 51.0),
];

/// 24 h of checks every 30 min for six targets, one outage on github.com, a
/// slow spell on 8.8.8.8, incidents and alert rules / events.
Future<AppDatabase> _seed({bool targets = true, bool incidents = true}) async {
  final db = AppDatabase(NativeDatabase.memory());
  if (!targets) return db;
  final now = DateTime.now();
  for (var t = 0; t < _targets.length; t++) {
    final (host, name, ms) = _targets[t];
    final id = await db
        .into(db.monitorTargets)
        .insert(MonitorTargetsCompanion.insert(host: host, name: name, sortOrder: Value(t), createdAt: now));
    for (var i = 47; i >= 0; i--) {
      final at = now.subtract(Duration(minutes: 30 * i + 1));
      final failed = incidents && host == 'github.com' && (i == 9 || i == 10);
      final slow = incidents && host == '8.8.8.8' && i >= 20 && i <= 22;
      await db
          .into(db.monitorChecks)
          .insert(
            MonitorChecksCompanion.insert(
              targetId: id,
              at: at,
              sent: 4,
              received: failed ? 0 : 4,
              rttAvg: Value(failed ? null : (slow ? ms * 3 + 40 : ms + (i % 5) * ms * .05)),
              rttMax: Value(failed ? null : ms + 8),
            ),
          );
    }
    if (incidents && host == 'github.com') {
      await db
          .into(db.incidents)
          .insert(
            IncidentsCompanion.insert(
              targetId: id,
              kind: 'down',
              title: 'github.com down',
              description: 'No reply to 8 checks',
              startedAt: now.subtract(const Duration(hours: 5, minutes: 31)),
              endedAt: Value(now.subtract(const Duration(hours: 4, minutes: 29))),
            ),
          );
    }
    if (incidents && host == '8.8.8.8') {
      await db
          .into(db.incidents)
          .insert(
            IncidentsCompanion.insert(
              targetId: id,
              kind: 'latency',
              title: '8.8.8.8 slow',
              description: 'Peaked at 214 ms (normal 58 ms)',
              startedAt: now.subtract(const Duration(hours: 11, minutes: 2)),
              endedAt: Value(now.subtract(const Duration(hours: 9, minutes: 40))),
            ),
          );
    }
  }
  Future<int> rule(String title, String target, String metric, double threshold, int forSec, int ch, bool on) => db
      .into(db.alertRules)
      .insert(
        AlertRulesCompanion.insert(
          title: title,
          target: target,
          metric: metric,
          threshold: Value(threshold),
          forSeconds: Value(forSec),
          channels: Value(ch),
          enabled: Value(on),
          createdAt: now,
          lastFiredAt: Value(
            metric == AlertMetric.latency ? now.subtract(const Duration(hours: 9, minutes: 50)) : null,
          ),
        ),
      );
  final latency = await rule('High latency', '8.8.8.8', AlertMetric.latency, 100, 30, 3, true);
  await rule('Packet loss', '*', AlertMetric.loss, 5, 60, 1, true);
  final down = await rule('Router down', '192.168.0.1', AlertMetric.down, 0, 10, 5, true);
  await rule('New LAN device', '*', AlertMetric.newDevice, 0, 30, 2, false);
  if (incidents) {
    await db
        .into(db.alertEvents)
        .insert(
          AlertEventsCompanion.insert(
            ruleId: latency,
            at: now.subtract(const Duration(hours: 9, minutes: 50)),
            message: '8.8.8.8 at 214 ms',
            value: const Value(214),
          ),
        );
    await db
        .into(db.alertEvents)
        .insert(
          AlertEventsCompanion.insert(
            ruleId: down,
            at: now.subtract(const Duration(days: 1, hours: 3)),
            message: 'Router unreachable for 10 s',
            dismissed: const Value(true),
          ),
        );
  }
  return db;
}

Future<ProviderContainer> _container(AppDatabase db, {MonitorMode mode = MonitorMode.app}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      databaseProvider.overrideWithValue(db),
      monitorRunnerProvider.overrideWith(() => _Runner(mode)),
    ],
  );
}

/// Lets drift streams emit, then re-pumps.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 120)));
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Pumps [app] at [size], waits for data, optionally taps, and writes a PNG.
Future<void> _shot(WidgetTester tester, String name, Widget app, Size size, {Future<void> Function()? interact}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  final key = GlobalKey();
  await tester.pumpWidget(RepaintBoundary(key: key, child: app));
  await _settle(tester);
  if (interact != null) {
    await interact();
    await _settle(tester);
  }
  await tester.runAsync(() async {
    final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    File('build/renders/$name.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(data!.buffer.asUint8List());
  });
}

Future<List<String>> _matrix(
  WidgetTester tester,
  String name,
  ProviderContainer c,
  Widget child,
  String location,
) async {
  final failures = <String>[];
  for (final d in {'phone': kPhone, 'tablet': kTablet}.entries) {
    for (final b in Brightness.values) {
      await _shot(
        tester,
        '${name}_${d.key}_${b.name}',
        _app(c, child, brightness: b, size: d.value, location: location),
        d.value,
      );
      final e = tester.takeException();
      if (e != null) failures.add('${d.key}/${b.name}: $e');
    }
  }
  return failures;
}

/// [pulseTestApp] with an optional text scale (the harness pins its own
/// MediaQuery, so a wrapper can't change it).
Widget _app(
  ProviderContainer c,
  Widget child, {
  Brightness brightness = Brightness.dark,
  Size size = kPhone,
  required String location,
  double textScale = 1,
}) => UncontrolledProviderScope(
  container: c,
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: buildPulseTheme(brightness),
    home: MediaQuery(
      data: MediaQueryData(
        size: size,
        padding: size.shortestSide < 600 ? const EdgeInsets.only(top: 40, bottom: 20) : EdgeInsets.zero,
        textScaler: TextScaler.linear(textScale),
        disableAnimations: true,
      ),
      child: PulseShell(location: location, child: child),
    ),
  ),
);

void main() {
  setUpAll(loadPulseFonts);

  Future<void> finish(WidgetTester tester, ProviderContainer c, AppDatabase db) async {
    await tester.pumpWidget(const SizedBox());
    c.dispose();
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('monitor', (tester) async {
    final db = (await tester.runAsync(_seed))!;
    final c = (await tester.runAsync(() => _container(db)))!;
    final failures = await _matrix(tester, 'monitor', c, const MonitorScreen(), '/monitor');

    // Target details sheet and the options sheet (phone, dark).
    for (final (name, finder) in [
      ('monitor_target_sheet', find.text('github.com')),
      ('monitor_options_sheet', find.byTooltip('Monitoring options')),
    ]) {
      await _shot(
        tester,
        '${name}_phone_dark',
        _app(c, const MonitorScreen(), size: kPhone, location: '/monitor'),
        kPhone,
        interact: () async {
          await tester.tap(finder.first);
          await tester.pump(const Duration(milliseconds: 400));
        },
      );
      final e = tester.takeException();
      if (e != null) failures.add('$name: $e');
    }
    await finish(tester, c, db);
    expect(failures, isEmpty);
  });

  testWidgets('monitor states', (tester) async {
    final failures = <String>[];
    // No targets.
    var db = (await tester.runAsync(() => _seed(targets: false)))!;
    var c = (await tester.runAsync(() => _container(db, mode: MonitorMode.idle)))!;
    for (final (d, size) in [('phone', kPhone), ('tablet', kTablet)]) {
      await _shot(
        tester,
        'monitor_empty_${d}_dark',
        _app(c, const MonitorScreen(), size: size, location: '/monitor'),
        size,
      );
      final e = tester.takeException();
      if (e != null) failures.add('empty/$d: $e');
    }
    await finish(tester, c, db);

    // Paused, no incidents, narrow phone with large text.
    db = (await tester.runAsync(() => _seed(incidents: false)))!;
    c = (await tester.runAsync(() => _container(db, mode: MonitorMode.paused)))!;
    await _shot(
      tester,
      'monitor_paused_phone_light',
      _app(c, const MonitorScreen(), brightness: Brightness.light, size: kPhone, location: '/monitor'),
      kPhone,
    );
    var e = tester.takeException();
    if (e != null) failures.add('paused: $e');
    await _shot(
      tester,
      'monitor_paused_narrow_dark',
      _app(c, const MonitorScreen(), size: const Size(360, 780), location: '/monitor', textScale: 1.3),
      const Size(360, 780),
    );
    e = tester.takeException();
    if (e != null) failures.add('narrow: $e');
    await _shot(
      tester,
      'monitor_portrait_tablet_dark',
      _app(c, const MonitorScreen(), size: const Size(800, 1280), location: '/monitor'),
      const Size(800, 1280),
    );
    e = tester.takeException();
    if (e != null) failures.add('portrait: $e');
    await finish(tester, c, db);
    expect(failures, isEmpty);
  });

  testWidgets('alerts', (tester) async {
    final db = (await tester.runAsync(_seed))!;
    final c = (await tester.runAsync(() => _container(db)))!;
    final failures = await _matrix(tester, 'alerts', c, const AlertsScreen(), '/alerts');
    for (final b in Brightness.values) {
      await _shot(
        tester,
        'alert_rule_phone_${b.name}',
        _app(c, const RuleEditorScreen(ruleId: 1), brightness: b, location: '/alerts/rule'),
        kPhone,
      );
      final e = tester.takeException();
      if (e != null) failures.add('rule/${b.name}: $e');
    }
    await _shot(
      tester,
      'alert_rule_new_narrow_dark',
      _app(c, const RuleEditorScreen(), size: const Size(360, 780), location: '/alerts/rule', textScale: 1.3),
      const Size(360, 780),
    );
    final e = tester.takeException();
    if (e != null) failures.add('rule/narrow: $e');
    await finish(tester, c, db);
    expect(failures, isEmpty);
  });
}
