import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'core/theme/wire_theme.dart';
import 'presentations/navigation/app_router.dart';
import 'providers/settings_provider.dart';

class PulseApp extends ConsumerWidget {
  const PulseApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(settingsProvider.select((s) => s.themeMode));
    final accent = ref.watch(accentColorProvider);
    return MaterialApp.router(
      title: 'Pulse',
      routerConfig: ref.watch(routerProvider),
      theme: buildWireTheme(Brightness.light, accent: accent),
      darkTheme: buildWireTheme(Brightness.dark, accent: accent),
      themeMode: themeMode,
      themeAnimationDuration: Duration.zero,
      debugShowCheckedModeBanner: false,
      // go_router and flutter_map still build against
      // package:flutter/material.dart, whose Theme is a different
      // InheritedWidget. The bridge forwards our theme to them.
      // ignore: deprecated_member_use
      builder: (context, child) => MaterialUiCompatibilityBridge(child: child!),
    );
  }
}
