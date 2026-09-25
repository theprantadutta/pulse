@Tags(['render'])
library;

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse/core/widgets/wire/wire.dart';
import 'package:pulse/presentations/screens/geo/geo_screen.dart';
import 'package:pulse/providers/geo_provider.dart';
import 'package:pulse/services/net/geo_ip.dart';

import 'render_harness.dart';

class _Fake extends GeoNotifier {
  @override
  GeoState build() => const GeoState(
    query: 'github.com',
    resolvedIp: '140.82.121.4',
    rttMs: 42,
    hops: 7,
    me: GeoInfo(ip: '103.112.54.8', lat: 23.81, lon: 90.41, city: 'Dhaka', source: 'ip-api.com'),
    target: GeoInfo(
      ip: '140.82.121.4', city: 'Singapore', countryCode: 'SG', timezone: 'Asia/Singapore',
      org: 'GitHub, Inc.', asn: 'AS36459', lat: 1.2897, lon: 103.8501, postal: '018989',
      hosting: true, source: 'ip-api.com',
    ),
  );
  @override
  Future<void> locateMe() async {}
}

void main() {
  setUpAll(() async {
    await loadWireFonts();
    // flutter_map's tile cache asks path_provider for a cache directory.
    final dir = Directory.systemTemp.createTempSync('pulse_tiles');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => dir.path,
    );
  });
  Widget app(Brightness b) => ProviderScope(
    overrides: [geoProvider.overrideWith(_Fake.new)],
    child: MaterialApp(debugShowCheckedModeBanner: false, theme: buildWireTheme(b), home: const Scaffold(body: GeoScreen())),
  );
  testWidgets('geo screens', (tester) async {
    await renderToPng(tester, 'geo_desktop_light', app(Brightness.light), size: const Size(1060, 736));
    await renderToPng(tester, 'geo_mobile_dark', app(Brightness.dark), size: const Size(390, 780));
  });
}
