@Tags(['render'])
library;

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/data/db/app_database.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse/presentations/screens/splash/splash_screen.dart';
import 'package:pulse/presentations/screens/tools/tools_hub_screen.dart';
import 'package:pulse/providers/boot_provider.dart';
import 'package:pulse/providers/database_provider.dart';
import 'package:pulse/providers/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'render_harness.dart';

void main() {
  setUpAll(loadPulseFonts);

  Future<ProviderContainer> seed() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    return ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        databaseProvider.overrideWithValue(AppDatabase(NativeDatabase.memory())),
        bootProvider.overrideWith(_IdleBoot.new),
      ],
    );
  }

  testWidgets('splash', (tester) async {
    final c = (await tester.runAsync(seed))!;
    final failures = <String>[];
    for (final d in {'phone': kPhone, 'tablet': kTablet, 'desktop_launch': const Size(720, 440)}.entries) {
      for (final b in Brightness.values) {
        await renderToPng(
          tester,
          'splash_${d.key}_${b.name}',
          pulseTestApp(c, const SplashScreen(), brightness: b, size: d.value, shell: false),
          size: d.value,
        );
        final e = tester.takeException();
        if (e != null) failures.add('${d.key}/${b.name}: $e');
      }
    }
    await tester.pumpWidget(const SizedBox());
    c.dispose();
    expect(failures, isEmpty);
  });

  testWidgets('tools hub', (tester) async {
    final c = (await tester.runAsync(seed))!;
    final failures = await renderMatrix(tester, 'tools', c, const ToolsHubScreen(), location: '/tools');
    await tester.pumpWidget(const SizedBox());
    c.dispose();
    await tester.pump(const Duration(seconds: 1));
    expect(failures, isEmpty);
  });
}

/// Boot that never runs (no platform channels in tests); shows the first step.
class _IdleBoot extends BootNotifier {
  @override
  BootState build() => const BootState(step: 1, total: 5, status: 'Opening database…');

  @override
  Future<void> run() async {}
}
