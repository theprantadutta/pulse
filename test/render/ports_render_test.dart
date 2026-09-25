@Tags(['render'])
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse/core/widgets/wire/wire.dart';
import 'package:pulse/presentations/screens/ports/ports_screen.dart';
import 'package:pulse/providers/port_scan_provider.dart';
import 'package:pulse/services/net/port_scanner.dart';

import 'render_harness.dart';

class _Fake extends PortScanNotifier {
  @override
  PortScanState build() {
    final ports = [for (var p = 1; p <= 1024; p++) p];
    return PortScanState(
      target: '192.168.1.24',
      preset: PortPreset.wellKnown,
      ports: ports,
      elapsed: const Duration(milliseconds: 3100),
      results: {
        for (final p in ports)
          p: switch (p) {
            22 => const PortResult(22, PortState.open, banner: 'SSH-2.0-OpenSSH_8.2p1'),
            80 => const PortResult(80, PortState.open, banner: 'nginx'),
            443 => const PortResult(443, PortState.open),
            1000 => const PortResult(1000, PortState.open),
            139 || 445 => PortResult(p, PortState.filtered),
            _ => PortResult(p, PortState.closed),
          },
      },
    );
  }
}

void main() {
  setUpAll(loadWireFonts);
  Widget app(Brightness b) => ProviderScope(
    overrides: [portScanProvider.overrideWith(_Fake.new)],
    child: MaterialApp(debugShowCheckedModeBanner: false, theme: buildWireTheme(b), home: const Scaffold(body: PortsScreen())),
  );
  testWidgets('ports screens', (tester) async {
    await renderToPng(tester, 'ports_desktop_light', app(Brightness.light), size: const Size(1060, 736));
    await renderToPng(tester, 'ports_mobile_dark', app(Brightness.dark), size: const Size(390, 780));
  });
}
