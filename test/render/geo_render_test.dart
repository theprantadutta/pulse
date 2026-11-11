@Tags(['render'])
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse/data/db/app_database.dart';
import 'package:pulse/presentations/screens/geo/geo_screen.dart';
import 'package:pulse/presentations/screens/geo/world_map.dart';
import 'package:pulse/providers/database_provider.dart';
import 'package:pulse/providers/geo_provider.dart';
import 'package:pulse/providers/settings_provider.dart';
import 'package:pulse/services/net/geo_ip.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'render_harness.dart';

const _me = GeoInfo(
  ip: '103.112.54.8',
  lat: 23.7104,
  lon: 90.4074,
  city: 'Dhaka',
  countryCode: 'BD',
  source: 'ip-api.com',
);

const _done = GeoState(
  query: 'github.com',
  resolvedIp: '20.205.243.166',
  rttMs: 55,
  hops: 19,
  me: _me,
  target: GeoInfo(
    ip: '20.205.243.166',
    city: 'Singapore',
    region: 'Central Singapore',
    country: 'Singapore',
    countryCode: 'SG',
    timezone: 'Asia/Singapore',
    org: 'Microsoft Azure Cloud (southeastasia)',
    isp: 'Microsoft Corporation',
    asn: 'AS8075',
    lat: 1.283,
    lon: 103.833,
    postal: '168812',
    hosting: true,
    source: 'ip-api.com',
  ),
);

class _Fake extends GeoNotifier {
  _Fake(this.initial);
  final GeoState initial;
  @override
  GeoState build() => initial;
  @override
  Future<void> locateMe() async {}
  @override
  Future<void> locate(String query) async {}
}

void main() {
  setUpAll(() async {
    await loadPulseFonts();
    WorldMap.prime(ByteData.sublistView(File(WorldMap.asset).readAsBytesSync()));
  });

  Future<ProviderContainer> seed(GeoState state, {bool lookups = true}) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        databaseProvider.overrideWithValue(AppDatabase(NativeDatabase.memory())),
        geoProvider.overrideWith(() => _Fake(state)),
      ],
    );
    if (!lookups) {
      await c.read(settingsProvider.notifier).update((s) => s.copyWith(publicIpLookups: false));
    }
    return c;
  }

  Future<void> run(
    WidgetTester tester,
    String name,
    GeoState state, {
    bool lookups = true,
    bool phoneOnly = false,
  }) async {
    final c = (await tester.runAsync(() => seed(state, lookups: lookups)))!;
    final failures = await renderMatrix(
      tester,
      name,
      c,
      GeoScreen(initialTarget: state.query.isEmpty ? null : state.query),
      location: '/geo',
      devices: phoneOnly ? const {'phone': kPhone} : const {'phone': kPhone, 'tablet': kTablet},
    );
    await tester.pumpWidget(const SizedBox());
    c.dispose();
    await tester.pump(const Duration(seconds: 1));
    expect(failures, isEmpty);
  }

  testWidgets('geo done', (tester) => run(tester, 'geo', _done));
  testWidgets('geo idle', (tester) => run(tester, 'geo_idle', const GeoState(me: _me)));
  testWidgets(
    'geo loading',
    (tester) => run(tester, 'geo_loading', const GeoState(query: 'cloudflare.com', me: _me, loading: true)),
  );
  testWidgets(
    'geo error',
    (tester) => run(
      tester,
      'geo_error',
      const GeoState(query: 'nope.invalid', me: _me, error: 'DNS lookup failed for nope.invalid (no address)'),
      phoneOnly: true,
    ),
  );
  testWidgets('geo lookups off', (tester) => run(tester, 'geo_off', const GeoState(), lookups: false));
  testWidgets(
    'geo far (antimeridian)',
    (tester) => run(
      tester,
      'geo_far',
      const GeoState(
        query: 'example.org',
        resolvedIp: '93.184.215.14',
        me: GeoInfo(ip: '1.1.1.1', lat: 35.68, lon: 139.69, city: 'Tokyo', source: 'ip-api.com'),
        target: GeoInfo(
          ip: '93.184.215.14',
          lat: 34.05,
          lon: -118.24,
          city: 'Los Angeles',
          countryCode: 'US',
          timezone: 'America/Los_Angeles',
          source: 'ip-api.com',
        ),
      ),
    ),
  );

  testWidgets('geo 360 dp at 1.3x text', (tester) async {
    final c = (await tester.runAsync(() => seed(_done)))!;
    const size = Size(360, 780);
    await renderToPng(
      tester,
      'geo_narrow_textscale',
      pulseTestApp(
        c,
        Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.3)),
            child: const GeoScreen(initialTarget: 'github.com'),
          ),
        ),
        size: size,
        location: '/geo',
      ),
      size: size,
    );
    final e = tester.takeException();
    await tester.pumpWidget(const SizedBox());
    c.dispose();
    await tester.pump(const Duration(seconds: 1));
    expect(e, isNull);
  });
}
