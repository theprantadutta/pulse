import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse/core/theme/pulse_theme.dart';

void main() {
  group('Expressive theme', () {
    test('uses the kit surfaces and Roboto Flex', () {
      final dark = buildPulseTheme(Brightness.dark);
      final light = buildPulseTheme(Brightness.light);
      expect(dark.colorScheme.surface, const Color(0xFF19121D));
      expect(light.colorScheme.surface, const Color(0xFFFFF7FA));
      expect(dark.textTheme.displayLarge!.fontFamily, pulseFontFamily);
    });

    test('hero pink is the same in light and dark', () {
      expect(
        buildPulseTheme(Brightness.dark).colorScheme.primaryFixedDim,
        buildPulseTheme(Brightness.light).colorScheme.primaryFixedDim,
      );
    });

    test('an accent swaps the hero family but keeps brand lime and lavender', () {
      final s = buildPulseTheme(Brightness.light, accent: PulseAccent.blue).colorScheme;
      expect(s.primaryFixedDim, PulseAccent.blue.fixedDim);
      expect(s.onPrimaryFixed, PulseAccent.blue.onFixed);
      expect(s.tertiaryFixedDim, PulseBrand.lime);
      expect(s.secondaryFixedDim, PulseBrand.lavender);
    });

    test('a dynamic scheme keeps the fixed brand roles', () {
      final dyn = ColorScheme.fromSeed(seedColor: const Color(0xFF00897B), brightness: Brightness.dark);
      final s = buildPulseTheme(Brightness.dark, dynamicScheme: dyn).colorScheme;
      expect(s.primary, dyn.primary);
      expect(s.primaryFixedDim, PulseBrand.pink);
      expect(s.tertiaryFixedDim, PulseBrand.lime);
    });

    test('unknown accent keys fall back to pink', () {
      expect(PulseAccent.of('ORANGE'), PulseAccent.pink);
      expect(PulseAccent.of(null), PulseAccent.pink);
    });

    test('latency colours follow the 10 / 40 ms thresholds', () {
      const t = PulseTokens.dark;
      expect(t.latencyColor(4), t.latFast);
      expect(t.latencyColor(25), t.latMedium);
      expect(t.latencyColor(80), t.latSlow);
      expect(t.latencyColor(null), t.latTimeout);
    });
  });
}
