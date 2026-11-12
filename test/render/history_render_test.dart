@Tags(['render'])
library;

import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse/data/db/app_database.dart';
import 'package:pulse/data/models/session_tool.dart';
import 'package:pulse/presentations/screens/history/history_screen.dart';
import 'package:pulse/presentations/screens/history/run_detail.dart';
import 'package:pulse/providers/database_provider.dart';
import 'package:pulse/providers/history_provider.dart';
import 'package:pulse/providers/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'render_harness.dart';

void main() {
  setUpAll(loadPulseFonts);

  /// History comes from a fixed list (no drift streams in fake async).
  Future<ProviderContainer> container([List<Session> sessions = const []]) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    return ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        databaseProvider.overrideWithValue(AppDatabase(NativeDatabase.memory())),
        historyProvider.overrideWith((ref) => Stream.value(sessions)),
      ],
    );
  }

  /// The kit's sample day (prototype data.js `history`).
  var traceId = 0;
  List<Session> seed() {
    final out = <Session>[];
    final now = DateTime.now();
    DateTime at(int h, int m, {int daysAgo = 0}) => DateTime(now.year, now.month, now.day - daysAgo, h, m);
    int save(
      SessionTool tool,
      String target,
      DateTime t, {
      String? label,
      double? avg,
      double? loss,
      String summary = '',
      List<double> trend = const [],
      Map<String, Object?> payload = const {},
    }) {
      out.insert(
        0,
        Session(
          id: out.length + 1,
          tool: tool.name,
          target: target,
          label: label,
          startedAt: t,
          endedAt: t.add(const Duration(seconds: 42)),
          avgMs: avg,
          lossPct: loss,
          summary: summary,
          trend: jsonEncode(trend),
          payload: jsonEncode(payload),
        ),
      );
      return out.length;
    }

    save(SessionTool.ping, '8.8.8.8', at(14, 52, daysAgo: 3), label: 'Google DNS', avg: 58, loss: 0);
    save(
      SessionTool.lan,
      '192.168.0.0/24',
      at(15, 5, daysAgo: 3),
      summary: '5 devices',
      payload: {
        'devices': [
          for (var i = 1; i <= 5; i++) {'ip': '192.168.0.$i', 'type': 'Device', 'rtt': 2.0 * i},
        ],
      },
    );
    save(
      SessionTool.ping,
      '8.8.8.8',
      at(16, 24),
      label: 'Google DNS',
      avg: 63,
      loss: 7.8,
      summary: '63 ms · 7.8%',
      payload: {
        'stats': {'sent': 90, 'received': 83, 'min': 41.0, 'avg': 63.0, 'max': 118.0, 'jitter': 9.4},
        'params': {'count': 0, 'intervalMs': 1000, 'timeoutSec': 2, 'packetSize': 56, 'ipVersion': 'auto'},
        'replies': [
          for (var i = 0; i < 60; i++)
            {
              'seq': i,
              'at': at(16, 24).millisecondsSinceEpoch + i * 1000,
              'state': i % 13 == 5 ? 'timeout' : 'ok',
              'rtt': i % 13 == 5 ? null : 45.0 + (i * 7) % 40,
              'ttl': 117,
            },
        ],
      },
    );
    save(
      SessionTool.lan,
      '192.168.0.0/24',
      at(16, 26),
      summary: '4 devices',
      payload: {
        'devices': [
          {'ip': '192.168.0.1', 'name': 'router.lan', 'vendor': 'TP-Link', 'type': 'Router', 'rtt': 1.8},
          {'ip': '192.168.0.12', 'name': 'pixel-8', 'vendor': 'Google', 'type': 'Phone', 'rtt': 6.0},
          {'ip': '192.168.0.20', 'type': 'Laptop', 'rtt': 3.2, 'new': true},
          {'ip': '192.168.0.31', 'vendor': 'Espressif', 'type': 'IoT', 'rtt': 14.0},
        ],
      },
    );
    // Traceroute to github.com: 21 hops, hops 9-10 silent, +55 ms at hop 11.
    final rtts = <double?>[2, 4, 6, 7, 9, 11, 13, 14, null, null, 69, 61, 58, 57, 56, 58, 57, 56, 58, 57, 56];
    final trace = save(
      SessionTool.trace,
      'github.com',
      at(16, 30),
      avg: 56,
      loss: 2 / 21 * 100,
      summary: '21 hops · BD → SG',
      payload: {
        'destination': '20.205.243.166',
        'reached': true,
        'hops': [
          for (var i = 0; i < rtts.length; i++)
            {
              'n': i + 1,
              // Home router, two ISP-private hops, then public BD / SG hops.
              'ip': rtts[i] == null
                  ? null
                  : i == 0
                  ? '192.168.1.1'
                  : i < 3
                  ? '10.$i.0.1'
                  : i < 10
                  ? '103.4.$i.1'
                  : '20.205.$i.1',
              'host': i == 0 ? 'router.lan' : null,
              'cc': rtts[i] == null ? null : (i < 10 ? 'BD' : 'SG'),
              'city': i == rtts.length - 1 ? 'Singapore' : null,
              'probes': rtts[i] == null ? [null, null, null] : [rtts[i], rtts[i]! + 1, rtts[i]! - 1],
              'reached': i == rtts.length - 1,
            },
        ],
      },
    );
    save(
      SessionTool.ports,
      'scanme.nmap.org',
      at(16, 31),
      summary: '2 open · 22, 80',
      payload: {
        'address': '45.33.32.156',
        'range': 'common',
        'scanned': 66,
        'filtered': 3,
        'open': [
          {'port': 22, 'state': 'open', 'banner': 'SSH-2.0-OpenSSH_6.6.1p1', 'ms': 212.0},
          {'port': 80, 'state': 'open', 'banner': null, 'ms': 208.0},
        ],
      },
    );
    for (final (m, d, u) in [(32, 8.4, 6.2), (33, 9.1, 7.0), (34, 9.3, 7.2)]) {
      save(
        SessionTool.speed,
        'Cloudflare DAC',
        at(16, m),
        avg: 18,
        summary: '${d.round()} ↓ · ${u.round()} ↑',
        trend: [6.1, 7.8, 8.4, 9.0, 9.2, 9.3],
        payload: {'down': d, 'up': u, 'ping': 18.0, 'jitter': 2.4, 'server': 'cloudflare', 'colo': 'DAC'},
      );
    }
    save(
      SessionTool.loss,
      '1.1.1.1',
      at(16, 35),
      avg: 21,
      loss: 0,
      summary: '0.0% · No loss',
      payload: {'sent': 90, 'lost': 0, 'late': 1, 'burst': 0, 'rate': 1, 'verdict': 'No loss: every packet came back.'},
    );
    save(
      SessionTool.geo,
      'github.com',
      at(16, 37),
      avg: 54,
      summary: 'Singapore',
      payload: {
        'geo': {
          'ip': '20.205.243.166',
          'city': 'Singapore',
          'country': 'Singapore',
          'countryCode': 'SG',
          'isp': 'Microsoft Corporation',
          'asn': 'AS8075',
          'timezone': 'Asia/Singapore',
          'lat': 1.2897,
          'lon': 103.8501,
          'source': 'ip-api.com',
        },
        'distanceKm': 2894.0,
        'hops': 21,
      },
    );
    traceId = trace;
    return out;
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('history', (tester) async {
    final c = (await tester.runAsync(() => container(seed())))!;
    c.read(selectedSessionIdProvider.notifier).select(traceId);
    final failures = await renderMatrix(tester, 'history', c, const HistoryScreen(), location: '/history');
    await settle(tester);
    c.dispose();
    expect(failures, isEmpty);
  });

  testWidgets('history run detail (phone)', (tester) async {
    final sessions = seed();
    final c = (await tester.runAsync(() => container(sessions)))!;
    final failures = <String>[];
    for (final tool in ['trace', 'ping', 'speed', 'ports', 'lan', 'geo', 'loss']) {
      final s = sessions.firstWhere((x) => x.tool == tool);
      for (final b in [Brightness.dark, if (tool == 'trace') Brightness.light]) {
        await renderToPng(
          tester,
          'history_detail_${tool}_phone_${b.name}',
          pulseTestApp(
            c,
            Scaffold(
              body: SafeArea(
                child: RunDetail(session: s, compact: true, onClose: () {}),
              ),
            ),
            brightness: b,
            location: '/history',
          ),
          size: kPhone,
        );
        final e = tester.takeException();
        if (e != null) failures.add('$tool/${b.name}: $e');
      }
    }
    await settle(tester);
    c.dispose();
    expect(failures, isEmpty);
  });

  testWidgets('history empty + filtered (phone)', (tester) async {
    final c = (await tester.runAsync(container))!;
    await renderToPng(
      tester,
      'history_empty_phone_dark',
      pulseTestApp(c, const HistoryScreen(), location: '/history'),
      size: kPhone,
    );
    await renderToPng(
      tester,
      'history_empty_tablet_light',
      pulseTestApp(c, const HistoryScreen(), location: '/history', brightness: Brightness.light, size: kTablet),
      size: kTablet,
    );
    c.read(historyFilterProvider.notifier).setSearch('nothing-matches');
    await renderToPng(
      tester,
      'history_nomatch_phone_light',
      pulseTestApp(c, const HistoryScreen(), location: '/history', brightness: Brightness.light),
      size: kPhone,
    );
    final e = tester.takeException();
    await settle(tester);
    c.dispose();
    expect(e, isNull);
  });
}
