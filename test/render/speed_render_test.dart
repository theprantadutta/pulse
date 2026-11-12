@Tags(['render'])
library;

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse/providers/connection_provider.dart';
import 'package:pulse/data/db/app_database.dart';
import 'package:pulse/presentations/screens/speed/speed_screen.dart';
import 'package:pulse/providers/database_provider.dart';
import 'package:pulse/providers/network_provider.dart';
import 'package:pulse/providers/settings_provider.dart';
import 'package:pulse/providers/speed_provider.dart';
import 'package:pulse/services/net/geo_ip.dart';
import 'package:pulse/services/net/network_details.dart';
import 'package:pulse/services/net/speed_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'render_harness.dart';

/// Kit sample: Cloudflare DAC, ping 37, jitter 27, downloading at 9.4 Mbps.
const _running = SpeedState(
  server: SpeedServer(
    id: 'cf',
    name: 'Cloudflare',
    location: 'nearest edge',
    downloadUrl: '',
    pingUrl: '',
    chunked: true,
  ),
  autoSelected: true,
  phase: SpeedPhase.download,
  liveMbps: 9.4,
  pingMs: 37,
  jitterMs: 27,
  progress: .62,
  colo: 'DAC',
);

class _Fake extends SpeedNotifier {
  _Fake(this.initial);
  final SpeedState initial;

  @override
  SpeedState build() => initial;

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
  setUpAll(loadPulseFonts);

  Future<ProviderContainer> seed(SpeedState state) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final at = DateTime(now.year, now.month, now.day, 16, 34);
    return ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        databaseProvider.overrideWithValue(AppDatabase(NativeDatabase.memory())),
        speedProvider.overrideWith(() => _Fake(state)),
        networkInfoProvider.overrideWith(_Net.new),
        speedHistoryProvider.overrideWith(
          (ref) => Stream.value([
            (at: at, down: 9.4, up: 7.1, ping: 37.0, server: 'Cloudflare DAC'),
            (at: at.subtract(const Duration(minutes: 1)), down: 9.2, up: 7.0, ping: 39.0, server: 'Cloudflare DAC'),
            (at: at.subtract(const Duration(minutes: 2)), down: 8.3, up: 6.4, ping: 42.0, server: 'Cloudflare DAC'),
          ]),
        ),
      ],
    );
  }

  Future<List<String>> render(WidgetTester tester, String name, SpeedState state, {bool phoneOnly = false}) async {
    final c = (await tester.runAsync(() => seed(state)))!;
    final failures = await renderMatrix(
      tester,
      name,
      c,
      const SpeedScreen(),
      location: '/speed',
      devices: phoneOnly ? const {'phone': kPhone} : const {'phone': kPhone, 'tablet': kTablet},
    );
    await tester.pumpWidget(const SizedBox());
    c.dispose();
    await tester.pump(const Duration(seconds: 1));
    return failures;
  }

  testWidgets('speed running', (tester) async {
    expect(await render(tester, 'speed', _running), isEmpty);
  });

  testWidgets('speed idle', (tester) async {
    expect(
      await render(tester, 'speed_idle', SpeedState(server: _running.server, autoSelected: true, colo: 'DAC')),
      isEmpty,
    );
  });

  testWidgets('speed done', (tester) async {
    expect(
      await render(
        tester,
        'speed_done',
        SpeedState(
          server: _running.server,
          phase: SpeedPhase.done,
          pingMs: 37,
          jitterMs: 27,
          downMbps: 9.4,
          upMbps: 7.1,
          progress: 1,
          colo: 'DAC',
        ),
      ),
      isEmpty,
    );
  });

  testWidgets('speed uploading + error', (tester) async {
    expect(
      await render(
        tester,
        'speed_upload',
        SpeedState(
          server: kSpeedServers[1],
          phase: SpeedPhase.upload,
          liveMbps: 212,
          pingMs: 18,
          jitterMs: 3.2,
          downMbps: 486,
          progress: .4,
        ),
        phoneOnly: true,
      ),
      isEmpty,
    );
    expect(
      await render(
        tester,
        'speed_error',
        SpeedState(
          server: _running.server,
          phase: SpeedPhase.done,
          error: 'Speed test failed: SocketException: Speed test server unreachable',
        ),
        phoneOnly: true,
      ),
      isEmpty,
    );
  });
}
