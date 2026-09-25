@Tags(['render'])
library;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse/core/widgets/wire/wire.dart';
import 'package:pulse/presentations/screens/settings/settings_screen.dart';
import 'package:pulse/providers/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'render_harness.dart';

void main() {
  setUpAll(() async {
    await loadWireFonts();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/package_info'),
      (call) async => {'appName': 'Pulse', 'packageName': 'com.pranta.pulse', 'version': '2.0.0', 'buildNumber': '12'},
    );
  });
  testWidgets('settings screens', (tester) async {
    SharedPreferences.setMockInitialValues({'wire.theme_mode': 'light'});
    final prefs = await tester.runAsync(SharedPreferences.getInstance);
    Widget app(Brightness b) => ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs!)],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildWireTheme(b),
        home: const Scaffold(body: SettingsScreen()),
      ),
    );
    await renderToPng(tester, 'settings_desktop_light', app(Brightness.light), size: const Size(1060, 736));
    await renderToPng(tester, 'settings_mobile_dark', app(Brightness.dark), size: const Size(390, 780));
  });
}
