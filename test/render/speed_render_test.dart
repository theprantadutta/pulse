@Tags(['render'])
library;

import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse/core/widgets/wire/wire.dart';
import 'package:pulse/presentations/screens/speed/speed_screen.dart';
import 'package:pulse/providers/connection_provider.dart';
import 'package:pulse/providers/network_provider.dart';
import 'package:pulse/providers/speed_provider.dart';
import 'package:pulse/services/net/geo_ip.dart';
import 'package:pulse/services/net/network_details.dart';
import 'package:pulse/services/net/speed_test.dart';

import 'render_harness.dart';

class _Fake extends SpeedNotifier {
  @override
  SpeedState build() {
    final r = Random(3);
    return SpeedState(
      server: kSpeedServers[6],
      autoSelected: true,
      phase: SpeedPhase.upload,
      liveMbps: 48.6,
      pingMs: 18,
      jitterMs: 3,
      downMbps: 212.4,
      samples: [
        for (var i = 0; i < 40; i++)
          SpeedSample(i < 24 ? 150 + r.nextDouble() * 90 : 30 + r.nextDouble() * 30, upload: i >= 24),
      ],
    );
  }

  @override
  Future<void> autoSelect() async {}
}

class _Net extends NetworkInfoNotifier {
  @override
  Future<NetworkSnapshot> build() async => NetworkSnapshot(
    link: const LinkDetails(kind: LinkKind.wifi),
    updatedAt: DateTime(2026),
    geo: const GeoInfo(ip: '103.112.54.8', lat: 23.81, lon: 90.41, source: 'test'),
  );
}

void main() {
  setUpAll(loadWireFonts);
  Widget app(Brightness b) => ProviderScope(
    overrides: [
      speedProvider.overrideWith(_Fake.new),
      networkInfoProvider.overrideWith(_Net.new),
      speedHistoryProvider.overrideWith(
        (ref) => Stream.value([
          (at: DateTime.now(), down: 208.1, up: 47.9),
          (at: DateTime.now().subtract(const Duration(days: 1)), down: 96.4, up: 41.0),
        ]),
      ),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildWireTheme(b),
      home: const Scaffold(body: SpeedScreen()),
    ),
  );
  testWidgets('speed screens', (tester) async {
    await renderToPng(tester, 'speed_desktop_light', app(Brightness.light), size: const Size(1060, 736));
    await renderToPng(tester, 'speed_mobile_light', app(Brightness.light), size: const Size(390, 780));
  });
}
