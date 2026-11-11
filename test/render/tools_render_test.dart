@Tags(['render'])
library;

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/data/db/app_database.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse/presentations/screens/tools/tools_hub_screen.dart';
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
      ],
    );
  }

  testWidgets('tools hub', (tester) async {
    final c = (await tester.runAsync(seed))!;
    final failures = await renderMatrix(tester, 'tools', c, const ToolsHubScreen(), location: '/tools');
    await tester.pumpWidget(const SizedBox());
    c.dispose();
    await tester.pump(const Duration(seconds: 1));
    expect(failures, isEmpty);
  });
}
