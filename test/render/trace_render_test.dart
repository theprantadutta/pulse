@Tags(['render'])
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse/core/widgets/wire/wire.dart';
import 'package:pulse/presentations/screens/trace/trace_screen.dart';
import 'package:pulse/providers/trace_provider.dart';
import 'package:pulse/services/net/traceroute.dart';

import 'render_harness.dart';

TraceHop _h(int n, String? ip, String? host, List<double?> p, String? cc, {String? city, bool reached = false}) {
  final h = TraceHop(n)
    ..ip = ip
    ..host = host
    ..countryCode = cc
    ..city = city
    ..reached = reached
    ..done = true;
  h.probes.addAll(p);
  return h;
}

class _Fake extends TraceNotifier {
  @override
  TraceState build() => TraceState(
    target: 'github.com',
    destination: '140.82.121.4',
    reached: true,
    finished: true,
    hops: [
      _h(1, '192.168.1.1', 'router.lan', [1, 1, 2], 'LAN'),
      _h(2, '10.60.17.1', null, [3, 2, 3], 'LAN'),
      _h(3, '103.112.54.1', 'gw.link3.net', [5, 6, 5], 'BD', city: 'Dhaka'),
      _h(4, null, null, [null, null, null], null),
      _h(5, '203.208.172.49', 'sg.pccw.net', [36, 35, 37], 'SG', city: 'Singapore'),
      _h(6, '140.82.121.1', null, [40, 41, 40], 'SG', city: 'Singapore'),
      _h(7, '140.82.121.4', 'lb-140-82-121-4-sin.github.com', [42, 42, 43], 'SG', city: 'Singapore', reached: true),
    ],
  );
}

void main() {
  setUpAll(loadWireFonts);
  Widget app(Brightness b) => ProviderScope(
    overrides: [traceProvider.overrideWith(_Fake.new)],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildWireTheme(b),
      home: const Scaffold(body: TraceScreen()),
    ),
  );
  testWidgets('trace screens', (tester) async {
    await renderToPng(tester, 'trace_desktop_light', app(Brightness.light), size: const Size(1060, 736));
    await renderToPng(tester, 'trace_mobile_light', app(Brightness.light), size: const Size(390, 780));
  });
}
