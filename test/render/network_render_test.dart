@Tags(['render'])
library;

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse/data/db/app_database.dart';
import 'package:pulse/presentations/screens/network/network_screen.dart';
import 'package:pulse/providers/boot_provider.dart';
import 'package:pulse/providers/connection_provider.dart';
import 'package:pulse/providers/database_provider.dart';
import 'package:pulse/providers/network_provider.dart';
import 'package:pulse/providers/ping_provider.dart';
import 'package:pulse/providers/settings_provider.dart';
import 'package:pulse/services/net/geo_ip.dart';
import 'package:pulse/services/net/network_details.dart';
import 'package:pulse/services/net/ping_prober.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'render_harness.dart';

class _Reader implements NetworkDetailsReader {
  const _Reader(this.d);
  final LinkDetails d;
  @override
  Future<LinkDetails> read({ConnectionSummary? summary}) async => d;
}

class _Geo extends GeoIpService {
  @override
  Future<GeoInfo> lookup([String? ip]) async => const GeoInfo(
    ip: '103.112.54.10',
    city: 'Dhaka',
    region: 'Dhaka Division',
    countryCode: 'BD',
    isp: 'Link3 Technologies',
    asn: 'AS23688',
    asName: 'LINK3-AS',
    source: 'ip-api.com',
  );
  @override
  Future<String?> publicIpv6() async => null;
}

class _Prober implements PingProber {
  @override
  Future<ProbeResult> probe(
    String host, {
    Duration timeout = const Duration(seconds: 2),
    int packetSize = 56,
    int ttl = 64,
    ProbeFamily family = ProbeFamily.auto,
  }) async => ProbeResult(status: ProbeStatus.ok, rttMs: host.endsWith('.1') ? 2.4 : 11);
}

class _IdleBoot extends BootNotifier {
  @override
  BootState build() => const BootState(step: 1, total: 5, status: 'Opening database…');

  @override
  Future<void> run() async {}
}

/// The kit's sample network (prototype/data.js): AUT-SYS, Wi-Fi 4, −56 dBm.
const _wifi = LinkDetails(
  kind: LinkKind.wifi,
  name: 'AUT-SYS',
  ssid: 'AUT-SYS',
  standard: 'WI-FI 4',
  band: '2.4 GHZ',
  channel: 6,
  security: 'WPA2',
  rssiDbm: -56,
  linkMbps: 52,
  localIpv4: '192.168.0.251',
  prefixLength: 24,
  gateway: '192.168.0.1',
  dns: ['192.168.0.1'],
);

const _ethernet = LinkDetails(
  kind: LinkKind.ethernet,
  name: 'Ethernet',
  adapter: 'Realtek PCIe GbE Family Controller',
  linkMbps: 1000,
  localIpv4: '192.168.0.42',
  prefixLength: 24,
  gateway: '192.168.0.1',
  dns: ['1.1.1.1', '8.8.8.8'],
  mac: '70:77:81:83:63:59',
  ipv6: ['2400:c600:1:2::42'],
);

const _cellular = LinkDetails(
  kind: LinkKind.cellular,
  localIpv4: '10.142.18.77',
  prefixLength: 30,
  gateway: '10.142.18.78',
  dns: ['10.10.10.10'],
);

void main() {
  setUpAll(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    await loadPulseFonts();
  });

  Future<ProviderContainer> seed(LinkDetails d) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    return ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        databaseProvider.overrideWithValue(AppDatabase(NativeDatabase.memory())),
        bootProvider.overrideWith(_IdleBoot.new),
        networkDetailsReaderProvider.overrideWithValue(_Reader(d)),
        geoIpServiceProvider.overrideWithValue(_Geo()),
        pingProberProvider.overrideWithValue(_Prober()),
        connectionProvider.overrideWith((ref) => const Stream.empty()),
      ],
    );
  }

  Future<List<String>> run(
    WidgetTester tester,
    String name,
    LinkDetails d, {
    Map<String, Size> devices = const {'phone': kPhone, 'tablet': kTablet},
  }) async {
    final c = (await tester.runAsync(() => seed(d)))!;
    // Let the snapshot and the background internet lookups settle.
    await tester.runAsync(() async {
      await c.read(networkInfoProvider.future);
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    final failures = await renderMatrix(tester, name, c, const NetworkScreen(), location: '/network', devices: devices);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
    await tester.pump(const Duration(seconds: 1));
    return failures;
  }

  testWidgets('network wifi (Android: MAC hidden)', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final failures = await run(tester, 'network', _wifi);
    debugDefaultTargetPlatformOverride = null;
    expect(failures, isEmpty);
  });

  testWidgets('network ethernet (desktop)', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    final failures = await run(tester, 'network_ethernet', _ethernet);
    debugDefaultTargetPlatformOverride = null;
    expect(failures, isEmpty);
  });

  testWidgets('network mobile data', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final failures = await run(tester, 'network_cellular', _cellular, devices: const {'phone': kPhone});
    debugDefaultTargetPlatformOverride = null;
    expect(failures, isEmpty);
  });

  testWidgets('network offline', (tester) async {
    final failures = await run(tester, 'network_offline', const LinkDetails(kind: LinkKind.none));
    expect(failures, isEmpty);
  });

  testWidgets('network at 360 dp and 1.3x text', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final c = (await tester.runAsync(() => seed(_wifi)))!;
    await tester.runAsync(() => c.read(networkInfoProvider.future));
    await renderToPng(
      tester,
      'network_small_text',
      pulseTestApp(
        c,
        Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.3)),
            child: const NetworkScreen(),
          ),
        ),
        size: const Size(360, 780),
        location: '/network',
      ),
      size: const Size(360, 780),
    );
    final e = tester.takeException();
    await tester.pumpWidget(const SizedBox());
    c.dispose();
    await tester.pump(const Duration(seconds: 1));
    debugDefaultTargetPlatformOverride = null;
    expect(e, isNull);
  });
}
