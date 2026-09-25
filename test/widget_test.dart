import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse/core/theme/wire_theme.dart';

void main() {
  test('Wire themes expose the colour extension and keep text on signal ink', () {
    for (final b in Brightness.values) {
      final theme = buildWireTheme(b);
      final w = theme.extension<WireColors>()!;
      expect(w.onSignal, WireColors.inkBlack);
      expect(w.signal, WireColors.signalOrange);
      expect(theme.scaffoldBackgroundColor, w.background);
    }
  });

  test('Dark theme is a strict paper/ink inversion', () {
    expect(WireColors.dark.background, WireColors.light.ink);
    expect(WireColors.dark.ink, WireColors.light.background);
  });

  test('Custom accent replaces only signal and its tint', () {
    final blue = WireColors.accents['BLUE']!;
    final w = buildWireTheme(Brightness.light, accent: blue)
        .extension<WireColors>()!;
    expect(w.signal, blue);
    expect(w.ink, WireColors.light.ink);
    expect(w.signalTint, isNot(WireColors.light.signalTint));
  });
}
