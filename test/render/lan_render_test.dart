@Tags(['render'])
library;

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse/data/db/app_database.dart' show AppDatabase;
import 'package:pulse/presentations/screens/lan/lan_screen.dart';
import 'package:pulse/providers/boot_provider.dart';
import 'package:pulse/providers/database_provider.dart';
import 'package:pulse/providers/lan_provider.dart';
import 'package:pulse/providers/settings_provider.dart';
import 'package:pulse/services/net/lan/lan_scanner.dart';
import 'package:pulse/services/net/port_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'render_harness.dart';

LanDevice _d(
  String ip,
  String? name,
  String? vendor,
  double? rtt, {
  bool gw = false,
  bool self = false,
  bool isNew = false,
  String? mac,
  DateTime? seen,
}) {
  final h = LanHost(ip: ip, hostname: name, vendor: vendor, rttMs: rtt, isGateway: gw, isSelf: self, mac: mac);
  return LanDevice(host: h, type: classifyDevice(h), isNew: isNew, firstSeen: seen ?? DateTime(2026, 11, 8, 15, 5));
}

/// Fixed state; select/scan are no-ops apart from the selection (no network).
class _Fake extends LanScanNotifier {
  _Fake(this.s);
  final LanScanState s;
  @override
  LanScanState build() => s;
  @override
  Future<void> scan() async {}
  @override
  void select(String ip) => state = state.copyWith(selectedIp: ip);
  @override
  Future<void> scanPorts(String ip) async {}
}

class _IdleBoot extends BootNotifier {
  @override
  BootState build() => const BootState(step: 1, total: 5, status: 'Opening database…');

  @override
  Future<void> run() async {}
}

void main() {
  setUpAll(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    await loadPulseFonts();
  });

  // The kit's sample (prototype/data.js), as seen from an Android phone.
  final kit = [
    _d('192.168.0.1', null, null, 3.9, gw: true),
    _d('192.168.0.43', null, null, 30),
    _d('192.168.0.251', null, null, 0.1, self: true),
  ];
  const kitPorts = {
    '192.168.0.1': [
      PortResult(53, PortState.open),
      PortResult(80, PortState.open),
      PortResult(443, PortState.open),
      PortResult(1900, PortState.open),
    ],
  };
  final kitDone = LanScanState(
    cidr: '192.168.0.0/24',
    total: 254,
    probed: 254,
    phase: 'done',
    elapsed: const Duration(milliseconds: 21600),
    devices: kit,
    selectedIp: '192.168.0.1',
    ports: kitPorts,
  );

  // A busier desktop network with MACs, vendors and a new device.
  final desk = [
    _d('192.168.1.1', null, 'TP-Link Systems Inc', 2, gw: true, mac: '28:87:BA:94:33:3B'),
    _d('192.168.1.10', 'realme-11-Pro', 'Realme Chongqing', 8),
    _d('192.168.1.24', 'ds220', 'Synology Incorporated', 3, mac: '00:11:32:A4:7E:0C'),
    _d('192.168.1.31', 'Living-TV', 'Samsung Electronics', 11),
    _d('192.168.1.42', 'Pranta-PC', 'Intel Corporate', 0, self: true, mac: '70:77:81:83:63:59'),
    _d('192.168.1.52', 'ESP32-Plug', 'Espressif Inc.', 22),
    _d('192.168.1.77', null, null, null, isNew: true, seen: null),
  ];
  final deskDone = LanScanState(
    cidr: '192.168.1.0/24',
    total: 254,
    probed: 254,
    phase: 'done',
    elapsed: const Duration(milliseconds: 4800),
    devices: desk,
    selectedIp: '192.168.1.24',
    ports: const {
      '192.168.1.24': [
        PortResult(22, PortState.open),
        PortResult(80, PortState.open),
        PortResult(443, PortState.open),
        PortResult(5000, PortState.open),
      ],
    },
  );
  final scanning = LanScanState(
    cidr: '192.168.0.0/24',
    total: 254,
    probed: 142,
    phase: 'probing',
    current: '192.168.0.142',
    devices: kit.take(2).toList(),
  );
  const empty = LanScanState(cidr: '192.168.0.0/24', total: 254, probed: 254, phase: 'done');
  const error = LanScanState(phase: 'done', error: 'Not connected to a local IPv4 network.');

  Future<ProviderContainer> seed(LanScanState s) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    return ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        databaseProvider.overrideWithValue(AppDatabase(NativeDatabase.memory())),
        bootProvider.overrideWith(_IdleBoot.new),
        lanScanProvider.overrideWith(() => _Fake(s)),
      ],
    );
  }

  Future<List<String>> run(
    WidgetTester tester,
    String name,
    LanScanState s, {
    Map<String, Size> devices = const {'phone': kPhone, 'tablet': kTablet},
  }) async {
    final c = (await tester.runAsync(() => seed(s)))!;
    final failures = await renderMatrix(tester, name, c, const LanScreen(), location: '/lan', devices: devices);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
    await tester.pump(const Duration(seconds: 1));
    return failures;
  }

  testWidgets('lan kit sample (Android)', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final failures = await run(tester, 'lan', kitDone);
    debugDefaultTargetPlatformOverride = null;
    expect(failures, isEmpty);
  });

  testWidgets('lan desktop network', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    final failures = await run(tester, 'lan_desktop', deskDone);
    debugDefaultTargetPlatformOverride = null;
    expect(failures, isEmpty);
  });

  testWidgets('lan scanning', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final failures = await run(tester, 'lan_scanning', scanning);
    debugDefaultTargetPlatformOverride = null;
    expect(failures, isEmpty);
  });

  testWidgets('lan empty and error', (tester) async {
    expect(await run(tester, 'lan_empty', empty, devices: const {'phone': kPhone}), isEmpty);
    expect(await run(tester, 'lan_error', error, devices: const {'phone': kPhone}), isEmpty);
  });

  testWidgets('lan at 360 dp, 1.3x text and an 840 dp window', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final c = (await tester.runAsync(() => seed(kitDone)))!;
    final failures = <String>[];
    for (final (name, size, scale) in [
      ('lan_small_text', const Size(360, 780), 1.3),
      ('lan_840', const Size(840, 700), 1.0),
    ]) {
      await renderToPng(
        tester,
        name,
        pulseTestApp(
          c,
          Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
              child: const LanScreen(),
            ),
          ),
          size: size,
          location: '/lan',
        ),
        size: size,
      );
      final e = tester.takeException();
      if (e != null) failures.add('$name: $e');
    }
    await tester.pumpWidget(const SizedBox());
    c.dispose();
    await tester.pump(const Duration(seconds: 1));
    debugDefaultTargetPlatformOverride = null;
    expect(failures, isEmpty);
  });
}
