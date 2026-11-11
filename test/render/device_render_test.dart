@Tags(['render'])
library;

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse/core/widgets/wire/wire.dart';
import 'package:pulse/data/db/app_database.dart';
import 'package:pulse/presentations/navigation/pulse_shell.dart';
import 'package:pulse/presentations/screens/alerts/alerts_screen.dart';
import 'package:pulse/presentations/screens/history/history_screen.dart';
import 'package:pulse/presentations/screens/loss/loss_screen.dart';
import 'package:pulse/presentations/screens/monitor/monitor_screen.dart';
import 'package:pulse/presentations/screens/ping/ping_configure.dart';
import 'package:pulse/presentations/screens/ping/ping_screen.dart';
import 'package:pulse/presentations/screens/ports/ports_screen.dart';
import 'package:pulse/presentations/screens/settings/settings_screen.dart';
import 'package:pulse/presentations/screens/speed/speed_screen.dart';
import 'package:pulse/presentations/screens/trace/trace_screen.dart';
import 'package:pulse/providers/connection_provider.dart';
import 'package:pulse/providers/database_provider.dart';
import 'package:pulse/providers/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'render_harness.dart';

/// Every screen inside the real app frame at real device sizes:
/// Galaxy A24 (1080×2340 px @ 450 dpi ≈ 384×832 dp) and
/// Galaxy Tab A9 (800×1340 px @ 213 dpi ≈ 600×1006 dp) in both orientations.
/// Phones are locked to portrait (see main.dart).
const _sizes = <String, Size>{
  'phone_portrait': Size(384, 832),
  'tab_portrait': Size(600, 1006),
  'tab_landscape': Size(1006, 600),
};

final _screens = <String, (String, Widget)>{
  'ping': ('/ping', const PingScreen()),
  'trace': ('/traceroute', const TraceScreen()),
  'ports': ('/ports', const PortsScreen()),
  'speed': ('/speed', const SpeedScreen()),
  'loss': ('/loss', const LossScreen()),
  'monitor': ('/monitor', const MonitorScreen()),
  'alerts': ('/alerts', const AlertsScreen()),
  'history': ('/history', const HistoryScreen()),
  'settings': ('/settings', const SettingsScreen()),
};

void main() {
  setUpAll(loadPulseFonts);

  Future<ProviderContainer> seed() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = AppDatabase(NativeDatabase.memory());
    return ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        databaseProvider.overrideWithValue(db),
        gatewayProvider.overrideWith((ref) async => '192.168.0.1'),
        connectionProvider.overrideWith((ref) => const Stream.empty()),
      ],
    );
  }

  Widget app(ProviderContainer c, Size size, String location, Widget child) => UncontrolledProviderScope(
    container: c,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildWireTheme(Brightness.dark),
      home: MediaQuery(
        data: MediaQueryData(size: size, padding: const EdgeInsets.only(top: 24, bottom: 20)),
        child: PulseShell(location: location, child: child),
      ),
    ),
  );

  for (final screen in _screens.entries) {
    testWidgets('device ${screen.key}', (tester) async {
      final c = (await tester.runAsync(seed))!;
      final failures = <String>[];
      for (final size in _sizes.entries) {
        await renderToPng(
          tester,
          'device_${screen.key}_${size.key}',
          app(c, size.value, screen.value.$1, screen.value.$2),
          size: size.value,
        );
        final e = tester.takeException();
        if (e != null) failures.add('${size.key}: $e');
      }
      await tester.pumpWidget(const SizedBox());
      c.dispose();
      await tester.pump(const Duration(seconds: 5));
      expect(failures, isEmpty);
    });
  }
}
