@Tags(['render'])
library;

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse/data/db/app_database.dart';
import 'package:pulse/presentations/screens/ports/ports_screen.dart';
import 'package:pulse/providers/database_provider.dart';
import 'package:pulse/providers/port_scan_provider.dart';
import 'package:pulse/providers/settings_provider.dart';
import 'package:pulse/services/net/port_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'render_harness.dart';

PortResult _result(int p) => switch (p) {
  22 => const PortResult(22, PortState.open, banner: 'SSH-2.0-OpenSSH_6.6.1p1 Ubuntu-2ubuntu2'),
  80 => const PortResult(80, PortState.open, banner: 'Apache/2.4.7 (Ubuntu)'),
  5060 || 49152 || 646 => PortResult(p, PortState.filtered),
  _ => PortResult(p, PortState.closed),
};

/// scanme.nmap.org, common ports (phone kit).
class _Common extends PortScanNotifier {
  @override
  PortScanState build() => PortScanState(
    target: 'scanme.nmap.org',
    address: '45.33.32.156',
    ports: kCommonPorts,
    elapsed: const Duration(milliseconds: 1200),
    results: {for (final p in kCommonPorts) p: _result(p)},
  );
}

/// 1–1024 (tablet kit).
class _WellKnown extends PortScanNotifier {
  @override
  PortScanState build() {
    final ports = [for (var p = 1; p <= 1024; p++) p];
    return PortScanState(
      target: 'scanme.nmap.org',
      address: '45.33.32.156',
      preset: PortPreset.wellKnown,
      ports: ports,
      elapsed: const Duration(milliseconds: 4900),
      results: {for (final p in ports) p: _result(p)},
    );
  }
}

class _Running extends PortScanNotifier {
  @override
  PortScanState build() {
    final ports = [for (var p = 1; p <= 1024; p++) p];
    return PortScanState(
      target: 'scanme.nmap.org',
      address: '45.33.32.156',
      preset: PortPreset.wellKnown,
      ports: ports,
      running: true,
      elapsed: const Duration(milliseconds: 1800),
      results: {for (final p in ports.take(380)) p: _result(p)},
    );
  }
}

class _NoneOpen extends PortScanNotifier {
  @override
  PortScanState build() => PortScanState(
    target: '192.168.0.1',
    address: '192.168.0.1',
    ports: kCommonPorts,
    elapsed: const Duration(milliseconds: 950),
    results: {for (final p in kCommonPorts) p: PortResult(p, PortState.closed)},
  );
}

class _Error extends PortScanNotifier {
  @override
  PortScanState build() =>
      const PortScanState(target: 'scanme.nmap.ogr', error: 'Could not resolve scanme.nmap.ogr (no address found)');
}

class _Idle extends PortScanNotifier {
  @override
  PortScanState build() => const PortScanState();
}

void main() {
  setUpAll(loadPulseFonts);

  Future<ProviderContainer> seed(PortScanNotifier Function() fake) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    return ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        databaseProvider.overrideWithValue(AppDatabase(NativeDatabase.memory())),
        portScanProvider.overrideWith(fake),
      ],
    );
  }

  Future<void> render(
    WidgetTester tester,
    String name,
    PortScanNotifier Function() fake, {
    Map<String, Size> devices = const {'phone': kPhone, 'tablet': kTablet},
  }) async {
    final c = (await tester.runAsync(() => seed(fake)))!;
    final failures = await renderMatrix(
      tester,
      name,
      c,
      PortsScreen(initialTarget: null, key: UniqueKey()),
      location: '/ports',
      devices: devices,
    );
    await tester.pumpWidget(const SizedBox());
    c.dispose();
    await tester.pump(const Duration(seconds: 1));
    expect(failures, isEmpty);
  }

  testWidgets('ports common', (tester) => render(tester, 'ports', _Common.new, devices: const {'phone': kPhone}));
  testWidgets('ports 1-1024', (tester) => render(tester, 'ports_range', _WellKnown.new));
  testWidgets('ports running', (tester) => render(tester, 'ports_running', _Running.new));
  testWidgets(
    'ports none open',
    (tester) => render(tester, 'ports_none', _NoneOpen.new, devices: const {'phone': kPhone}),
  );
  testWidgets('ports error', (tester) => render(tester, 'ports_error', _Error.new, devices: const {'phone': kPhone}));
  testWidgets('ports idle', (tester) => render(tester, 'ports_idle', _Idle.new));
}
