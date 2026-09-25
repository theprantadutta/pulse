@Tags(['render'])
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse/core/widgets/wire/wire.dart';
import 'package:pulse/presentations/screens/network/network_screen.dart';
import 'package:pulse/providers/connection_provider.dart';
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

const _wifi = LinkDetails(
  kind: LinkKind.wifi,
  name: 'Pranta',
  ssid: 'Pranta',
  standard: 'WI-FI 4',
  band: '2.4 GHZ',
  channel: 2,
  security: 'WPA2',
  signalPercent: 74,
  linkMbps: 150,
  localIpv4: '192.168.0.103',
  prefixLength: 24,
  gateway: '192.168.0.1',
  dns: ['192.168.0.1'],
  mac: '70:77:81:83:63:59',
);

void main() {
  setUpAll(loadWireFonts);

  Future<void> shot(WidgetTester tester, String name, LinkDetails d, Brightness b, Size size) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await tester.runAsync(SharedPreferences.getInstance);
    await renderToPng(
      tester,
      name,
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs!),
          networkDetailsReaderProvider.overrideWithValue(_Reader(d)),
          geoIpServiceProvider.overrideWithValue(_Geo()),
          pingProberProvider.overrideWithValue(_Prober()),
          connectionProvider.overrideWith((ref) => const Stream.empty()),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildWireTheme(b),
          home: const Scaffold(body: NetworkScreen()),
        ),
      ),
      size: size,
    );
  }

  testWidgets('network screens', (tester) async {
    await shot(tester, 'network_desktop_light', _wifi, Brightness.light, const Size(1060, 736));
    await shot(tester, 'network_mobile_light', _wifi, Brightness.light, const Size(390, 780));
    await shot(tester, 'network_desktop_dark', _wifi, Brightness.dark, const Size(1060, 736));
    await shot(
      tester,
      'network_offline',
      const LinkDetails(kind: LinkKind.none),
      Brightness.light,
      const Size(1060, 736),
    );
  });
}
