@Tags(['render'])
library;

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse/data/db/app_database.dart';
import 'package:pulse/presentations/screens/trace/trace_screen.dart';
import 'package:pulse/providers/database_provider.dart';
import 'package:pulse/providers/settings_provider.dart';
import 'package:pulse/providers/trace_provider.dart';
import 'package:pulse/services/net/traceroute.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

/// The kit's github.com route: 21 hops, BD → SG, timeouts at 09–10, +55 ms jump.
List<TraceHop> _route() => [
  _h(1, '192.168.0.1', null, [3.9, 4.5, 4.7], 'LAN'),
  _h(2, '192.168.111.1', null, [3.7, 4, 4.9], 'LAN'),
  _h(3, '203.82.207.225', 'gw4.gmts.kdsgroup.net', [4, 4.8, 4.5], 'BD', city: 'Dhaka'),
  _h(4, '10.42.192.205', null, [4.5, 5.2, 4.8], 'LAN'),
  _h(5, '10.42.193.81', null, [4.9, 4.4, 5.1], 'LAN'),
  _h(6, '10.42.193.217', null, [5.3, 5, 4.9], 'LAN'),
  _h(7, '10.44.10.5', null, [14, 12, 13], 'LAN'),
  _h(8, '202.22.200.101', null, [6, 5.6, 5.4], 'BD', city: 'Dhaka'),
  _h(9, null, null, [null, null, null], null),
  _h(10, null, null, [null, null, null], null),
  for (var n = 11; n <= 20; n++)
    _h(
      n,
      '203.208.172.${40 + n}',
      'sg-$n.pccw.net',
      [52 + n * .3, 53 + n * .3, 52.5 + n * .3],
      'SG',
      city: 'Singapore',
    ),
  _h(21, '20.205.243.166', null, [56, 55, 57], 'SG', city: 'Singapore', reached: true),
];

class _Done extends TraceNotifier {
  @override
  TraceState build() =>
      TraceState(target: 'github.com', destination: '20.205.243.166', reached: true, finished: true, hops: _route());
}

class _Running extends TraceNotifier {
  @override
  TraceState build() {
    final hops = _route().take(8).toList();
    final probing = TraceHop(9);
    return TraceState(target: 'github.com', destination: '20.205.243.166', running: true, hops: [...hops, probing]);
  }
}

class _Idle extends TraceNotifier {
  @override
  TraceState build() => const TraceState();
}

class _Error extends TraceNotifier {
  @override
  TraceState build() =>
      const TraceState(target: 'githb.cmo', finished: true, error: 'Could not resolve githb.cmo (no address found)');
}

void main() {
  setUpAll(loadPulseFonts);

  Future<ProviderContainer> seed(TraceNotifier Function() fake) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    return ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        databaseProvider.overrideWithValue(AppDatabase(NativeDatabase.memory())),
        traceProvider.overrideWith(fake),
      ],
    );
  }

  Future<void> render(WidgetTester tester, String name, TraceNotifier Function() fake, {bool phoneOnly = false}) async {
    final c = (await tester.runAsync(() => seed(fake)))!;
    final failures = await renderMatrix(
      tester,
      name,
      c,
      const TraceScreen(),
      location: '/traceroute',
      devices: phoneOnly ? const {'phone': kPhone} : const {'phone': kPhone, 'tablet': kTablet},
    );
    await tester.pumpWidget(const SizedBox());
    c.dispose();
    await tester.pump(const Duration(seconds: 1));
    expect(failures, isEmpty);
  }

  testWidgets('trace done', (tester) => render(tester, 'trace', _Done.new));
  testWidgets('trace running', (tester) => render(tester, 'trace_running', _Running.new));
  testWidgets('trace idle', (tester) => render(tester, 'trace_idle', _Idle.new, phoneOnly: true));
  testWidgets('trace error', (tester) => render(tester, 'trace_error', _Error.new, phoneOnly: true));
}
