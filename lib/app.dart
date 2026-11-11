import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'core/theme/pulse_theme.dart';
import 'presentations/navigation/app_router.dart';
import 'providers/settings_provider.dart';

class PulseApp extends ConsumerWidget {
  const PulseApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(settingsProvider.select((s) => s.themeMode));
    final accent = PulseAccent.of(ref.watch(settingsProvider.select((s) => s.accent)));
    final useDynamic = ref.watch(settingsProvider.select((s) => s.dynamicColor));
    final motion = ref.watch(settingsProvider.select((s) => s.expressiveMotion));
    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) => MaterialApp.router(
        title: 'Pulse',
        routerConfig: ref.watch(routerProvider),
        theme: buildPulseTheme(Brightness.light, accent: accent, dynamicScheme: useDynamic ? lightDynamic : null),
        darkTheme: buildPulseTheme(Brightness.dark, accent: accent, dynamicScheme: useDynamic ? darkDynamic : null),
        themeMode: themeMode,
        debugShowCheckedModeBanner: false,
        builder: (context, child) {
          // Settings › Expressive motion off behaves like the system's
          // "remove animations": every loop rests and entrances are instant.
          final mq = MediaQuery.of(context);
          final Widget app = motion ? child! : MediaQuery(data: mq.copyWith(disableAnimations: true), child: child!);
          // Any dependency still built against package:flutter/material.dart
          // reads a different Theme InheritedWidget; the bridge forwards ours.
          // ignore: deprecated_member_use
          return MaterialUiCompatibilityBridge(child: app);
        },
      ),
    );
  }
}
