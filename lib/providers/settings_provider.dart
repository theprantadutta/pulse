import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/theme/wire_theme.dart';
import '../data/models/app_settings.dart';
import '../data/settings_store.dart';

/// Overridden in main() with the instance loaded before runApp.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw StateError('sharedPreferencesProvider must be overridden'),
);

final settingsStoreProvider = Provider<SettingsStore>(
  (ref) => SettingsStore(ref.watch(sharedPreferencesProvider)),
);

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(
  SettingsNotifier.new,
);

class SettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() => ref.watch(settingsStoreProvider).load();

  Future<void> update(AppSettings Function(AppSettings s) change) async {
    state = change(state);
    await ref.read(settingsStoreProvider).save(state);
  }

  Future<void> setThemeMode(ThemeMode mode) =>
      update((s) => s.copyWith(themeMode: mode));

  Future<void> setAccent(String key) => update((s) => s.copyWith(accent: key));
}

/// The resolved accent colour for the current settings.
final accentColorProvider = Provider<Color>((ref) {
  final key = ref.watch(settingsProvider.select((s) => s.accent));
  return WireColors.accents[key] ?? WireColors.signalOrange;
});
