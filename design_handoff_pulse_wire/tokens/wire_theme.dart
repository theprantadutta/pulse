// Pulse / Wire theme — drop into lib/core/theme/wire_theme.dart
// Fonts: bundle Archivo (variable, wdth+wght axes) and Space Mono in assets/fonts
// and declare them in pubspec.yaml as families 'Archivo' and 'SpaceMono'.
import 'dart:ui' show FontVariation;
import 'package:flutter/material.dart';

@immutable
class WireColors extends ThemeExtension<WireColors> {
  const WireColors({
    required this.background, required this.ink, required this.signal,
    required this.onSignal, required this.signalTint, required this.surfaceInput,
    required this.mutedRow, required this.gridLine, required this.filtered,
    required this.text2, required this.text3, required this.degraded,
    required this.chartBar,
  });

  final Color background, ink, signal, onSignal, signalTint, surfaceInput,
      mutedRow, gridLine, filtered, text2, text3, degraded, chartBar;

  static const light = WireColors(
    background: Color(0xFFF2F0EB), ink: Color(0xFF111111), signal: Color(0xFFE8612C),
    onSignal: Color(0xFF111111), signalTint: Color(0xFFF6C9B3), surfaceInput: Color(0xFFFFFFFF),
    mutedRow: Color(0xFFE4E0D8), gridLine: Color(0xFFD9D5CC), filtered: Color(0xFF8E8A82),
    text2: Color(0xFF4A4740), text3: Color(0xFF6B675E), degraded: Color(0xFFC98A2E),
    chartBar: Color(0xFF111111),
  );

  static const dark = WireColors(
    background: Color(0xFF111111), ink: Color(0xFFF2F0EB), signal: Color(0xFFE8612C),
    onSignal: Color(0xFF111111), signalTint: Color(0xFF4A2616), surfaceInput: Color(0xFF1C1C1C),
    mutedRow: Color(0xFF262523), gridLine: Color(0xFF2E2D2A), filtered: Color(0xFF6E6A63),
    text2: Color(0xFFB5B0A6), text3: Color(0xFF8C877D), degraded: Color(0xFFE0A445),
    chartBar: Color(0xFFF2F0EB),
  );

  WireColors withSignal(Color c) => copyWith(signal: c);

  @override
  WireColors copyWith({Color? background, Color? ink, Color? signal, Color? onSignal,
      Color? signalTint, Color? surfaceInput, Color? mutedRow, Color? gridLine,
      Color? filtered, Color? text2, Color? text3, Color? degraded, Color? chartBar}) {
    return WireColors(
      background: background ?? this.background, ink: ink ?? this.ink,
      signal: signal ?? this.signal, onSignal: onSignal ?? this.onSignal,
      signalTint: signalTint ?? this.signalTint, surfaceInput: surfaceInput ?? this.surfaceInput,
      mutedRow: mutedRow ?? this.mutedRow, gridLine: gridLine ?? this.gridLine,
      filtered: filtered ?? this.filtered, text2: text2 ?? this.text2, text3: text3 ?? this.text3,
      degraded: degraded ?? this.degraded, chartBar: chartBar ?? this.chartBar,
    );
  }

  @override
  WireColors lerp(ThemeExtension<WireColors>? other, double t) {
    if (other is! WireColors) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return WireColors(
      background: l(background, other.background), ink: l(ink, other.ink),
      signal: l(signal, other.signal), onSignal: l(onSignal, other.onSignal),
      signalTint: l(signalTint, other.signalTint), surfaceInput: l(surfaceInput, other.surfaceInput),
      mutedRow: l(mutedRow, other.mutedRow), gridLine: l(gridLine, other.gridLine),
      filtered: l(filtered, other.filtered), text2: l(text2, other.text2), text3: l(text3, other.text3),
      degraded: l(degraded, other.degraded), chartBar: l(chartBar, other.chartBar),
    );
  }
}

/// Type roles. `width` maps to Archivo's wdth axis (62 = most condensed).
class WireType {
  static TextStyle display(double size, {double width = 62, FontWeight weight = FontWeight.w900}) =>
      TextStyle(fontFamily: 'Archivo', fontSize: size, height: 0.85, fontWeight: weight,
          fontVariations: [FontVariation('wdth', width), FontVariation('wght', weight.value.toDouble())]);

  static TextStyle hero(double size) => display(size);                       // 150–210 desktop, 150–190 mobile
  static TextStyle stat(double size) => display(size, width: 70);            // 22–40
  static TextStyle title(double size) => display(size, width: 75);           // 26–32
  static TextStyle nav(double size) => display(size, width: 80, weight: FontWeight.w800); // 16–20, UPPERCASE
  static TextStyle data(double size) => TextStyle(fontFamily: 'SpaceMono', fontSize: size, fontWeight: FontWeight.w700);
  static TextStyle body(double size) => TextStyle(fontFamily: 'SpaceMono', fontSize: size, height: 1.5);
  static TextStyle label() => const TextStyle(fontFamily: 'SpaceMono', fontSize: 11, fontWeight: FontWeight.w700);
}

const double kWireBorder = 2;
const double kWireHairline = 1;

ThemeData buildWireTheme(Brightness b, {Color? accent}) {
  final w = (b == Brightness.light ? WireColors.light : WireColors.dark)
      .withSignal(accent ?? const Color(0xFFE8612C));
  final side = BorderSide(color: w.ink, width: kWireBorder);
  return ThemeData(
    useMaterial3: true,
    brightness: b,
    scaffoldBackgroundColor: w.background,
    fontFamily: 'SpaceMono',
    colorScheme: ColorScheme(
      brightness: b, primary: w.signal, onPrimary: w.onSignal,
      secondary: w.ink, onSecondary: w.background, error: w.signal, onError: w.onSignal,
      surface: w.background, onSurface: w.ink, outline: w.ink,
    ),
    extensions: [w],
    dividerTheme: DividerThemeData(color: w.ink, thickness: kWireHairline, space: 0),
    inputDecorationTheme: InputDecorationTheme(
      filled: true, fillColor: w.surfaceInput,
      border: OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: side),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: side),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: w.signal, width: kWireBorder)),
    ),
    filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(
      backgroundColor: w.signal, foregroundColor: w.onSignal,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero, side: side),
      textStyle: WireType.nav(18), minimumSize: const Size(0, 56),
    )),
    outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(
      foregroundColor: w.ink, side: side, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      textStyle: WireType.nav(16), minimumSize: const Size(0, 48),
    )),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? w.signal : w.ink),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? w.ink : Colors.transparent),
      trackOutlineColor: WidgetStatePropertyAll(w.ink),
    ),
  );
}

extension WireContext on BuildContext {
  WireColors get wire => Theme.of(this).extension<WireColors>()!;
}
