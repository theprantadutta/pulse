@Tags(['render'])
library;

import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse/data/db/app_database.dart';
import 'package:pulse/presentations/screens/settings/settings_screen.dart';
import 'package:pulse/providers/database_provider.dart';
import 'package:pulse/providers/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'render_harness.dart';

void main() {
  setUpAll(() async {
    await loadPulseFonts();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/package_info'),
      (call) async => {'appName': 'Pulse', 'packageName': 'com.pranta.pulse', 'version': '1.0.0', 'buildNumber': '1'},
    );
  });

  Future<ProviderContainer> container({bool dynamicSupport = true}) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    return ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        databaseProvider.overrideWithValue(AppDatabase(NativeDatabase.memory())),
        dynamicColorSupportProvider.overrideWith((ref) async => dynamicSupport),
      ],
    );
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('settings', (tester) async {
    final c = (await tester.runAsync(container))!;
    await tester.runAsync(() => c.read(packageInfoProvider.future));
    await tester.runAsync(() => c.read(dynamicColorSupportProvider.future));
    final failures = await renderMatrix(tester, 'settings', c, const SettingsScreen(), location: '/settings');
    await settle(tester);
    c.dispose();
    expect(failures, isEmpty);
  });

  testWidgets('settings sections (tablet) and long phone page', (tester) async {
    final c = (await tester.runAsync(() => container(dynamicSupport: false)))!;
    await tester.runAsync(() => c.read(packageInfoProvider.future));
    await tester.runAsync(() => c.read(dynamicColorSupportProvider.future));
    final failures = <String>[];
    for (final s in SettingsSection.available.skip(1)) {
      await renderToPng(
        tester,
        'settings_${s.name}_tablet_dark',
        pulseTestApp(
          c,
          SettingsScreen(initialSection: s),
          size: kTablet,
          location: '/settings',
        ),
        size: kTablet,
      );
      final e = tester.takeException();
      if (e != null) failures.add('${s.name}: $e');
    }
    // The whole phone column in one tall image, dynamic colour unsupported.
    await renderToPng(
      tester,
      'settings_full_phone_light',
      pulseTestApp(
        c,
        const SettingsScreen(),
        brightness: Brightness.light,
        size: const Size(390, 3400),
        location: '/settings',
      ),
      size: const Size(390, 3400),
    );
    final e = tester.takeException();
    if (e != null) failures.add('full: $e');
    // 360 dp at 1.3x text.
    await renderToPng(
      tester,
      'settings_small_phone_dark',
      pulseTestApp(
        c,
        Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.3)),
            child: const SettingsScreen(),
          ),
        ),
        size: const Size(360, 780),
        location: '/settings',
      ),
      size: const Size(360, 780),
    );
    final e2 = tester.takeException();
    if (e2 != null) failures.add('small: $e2');
    await settle(tester);
    c.dispose();
    expect(failures, isEmpty);
  });
}
