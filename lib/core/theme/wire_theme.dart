// Pulse / Wire theme.
// Fonts are bundled in assets/fonts and declared in pubspec.yaml as the
// families 'Archivo' (variable, wdth + wght axes) and 'SpaceMono'.
// This is the only file allowed to hold hex colour values.
import 'package:material_ui/material_ui.dart';

@immutable
class WireColors extends ThemeExtension<WireColors> {
  const WireColors({
    required this.background,
    required this.ink,
    required this.signal,
    required this.onSignal,
    required this.signalTint,
    required this.surfaceInput,
    required this.mutedRow,
    required this.gridLine,
    required this.filtered,
    required this.text2,
    required this.text3,
    required this.degraded,
    required this.chartBar,
    required this.backdrop,
  });

  final Color background,
      ink,
      signal,
      onSignal,
      signalTint,
      surfaceInput,
      mutedRow,
      gridLine,
      filtered,
      text2,
      text3,
      degraded,
      chartBar,
      backdrop;

  /// Paper — the fixed brand paper colour, independent of theme brightness.
  static const paper = Color(0xFFF2F0EB);

  /// Ink — the fixed brand ink colour, independent of theme brightness.
  static const inkBlack = Color(0xFF111111);

  /// The default Signal orange from the original Pulse logo.
  static const signalOrange = Color(0xFFE8612C);

  /// User-selectable accents (Settings → Appearance). Only `signal` changes.
  static const accents = <String, Color>{
    'ORANGE': signalOrange,
    'BLUE': Color(0xFF3B6FE0),
    'GREEN': Color(0xFF1E9E62),
    'YELLOW': Color(0xFFD6B400),
  };

  static const light = WireColors(
    background: paper,
    ink: inkBlack,
    signal: signalOrange,
    onSignal: inkBlack,
    signalTint: Color(0xFFF6C9B3),
    surfaceInput: Color(0xFFFFFFFF),
    mutedRow: Color(0xFFE4E0D8),
    gridLine: Color(0xFFD9D5CC),
    filtered: Color(0xFF8E8A82),
    text2: Color(0xFF4A4740),
    text3: Color(0xFF6B675E),
    degraded: Color(0xFFC98A2E),
    chartBar: inkBlack,
    backdrop: Color(0xFFCFCBC2),
  );

  static const dark = WireColors(
    background: inkBlack,
    ink: paper,
    signal: signalOrange,
    onSignal: inkBlack,
    signalTint: Color(0xFF4A2616),
    surfaceInput: Color(0xFF1C1C1C),
    mutedRow: Color(0xFF262523),
    gridLine: Color(0xFF2E2D2A),
    filtered: Color(0xFF6E6A63),
    text2: Color(0xFFB5B0A6),
    text3: Color(0xFF8C877D),
    degraded: Color(0xFFE0A445),
    chartBar: paper,
    backdrop: Color(0xFF000000),
  );

  /// Replaces the accent. The tint is re-derived so selected/warning rows
  /// follow the chosen accent in both themes.
  WireColors withSignal(Color c, Brightness b) {
    if (c == signalOrange) return copyWith(signal: c);
    final tint = b == Brightness.light
        ? Color.lerp(c, paper, 0.62)!
        : Color.lerp(c, inkBlack, 0.70)!;
    return copyWith(signal: c, signalTint: tint);
  }

  @override
  WireColors copyWith({
    Color? background,
    Color? ink,
    Color? signal,
    Color? onSignal,
    Color? signalTint,
    Color? surfaceInput,
    Color? mutedRow,
    Color? gridLine,
    Color? filtered,
    Color? text2,
    Color? text3,
    Color? degraded,
    Color? chartBar,
    Color? backdrop,
  }) {
    return WireColors(
      background: background ?? this.background,
      ink: ink ?? this.ink,
      signal: signal ?? this.signal,
      onSignal: onSignal ?? this.onSignal,
      signalTint: signalTint ?? this.signalTint,
      surfaceInput: surfaceInput ?? this.surfaceInput,
      mutedRow: mutedRow ?? this.mutedRow,
      gridLine: gridLine ?? this.gridLine,
      filtered: filtered ?? this.filtered,
      text2: text2 ?? this.text2,
      text3: text3 ?? this.text3,
      degraded: degraded ?? this.degraded,
      chartBar: chartBar ?? this.chartBar,
      backdrop: backdrop ?? this.backdrop,
    );
  }

  @override
  WireColors lerp(ThemeExtension<WireColors>? other, double t) {
    if (other is! WireColors) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return WireColors(
      background: l(background, other.background),
      ink: l(ink, other.ink),
      signal: l(signal, other.signal),
      onSignal: l(onSignal, other.onSignal),
      signalTint: l(signalTint, other.signalTint),
      surfaceInput: l(surfaceInput, other.surfaceInput),
      mutedRow: l(mutedRow, other.mutedRow),
      gridLine: l(gridLine, other.gridLine),
      filtered: l(filtered, other.filtered),
      text2: l(text2, other.text2),
      text3: l(text3, other.text3),
      degraded: l(degraded, other.degraded),
      chartBar: l(chartBar, other.chartBar),
      backdrop: l(backdrop, other.backdrop),
    );
  }
}

/// Type roles. `width` maps to Archivo's wdth axis (62 = most condensed).
class WireType {
  WireType._();

  /// Geometric glyphs (■ ▶ ↻ ● ✓ ▲) missing from Archivo and Space Mono.
  static const fallback = ['WireGlyphs'];

  static TextStyle display(
    double size, {
    double width = 62,
    FontWeight weight = FontWeight.w900,
    double height = 0.85,
  }) => TextStyle(
    fontFamily: 'Archivo',
    fontFamilyFallback: fallback,
    fontSize: size,
    height: height,
    fontWeight: weight,
    letterSpacing: 0,
    fontVariations: [
      FontVariation('wdth', width),
      FontVariation('wght', weight.value.toDouble()),
    ],
  );

  /// 150–210 desktop, 150–190 mobile.
  static TextStyle hero(double size) => display(size);

  /// 22–40.
  static TextStyle stat(double size) => display(size, width: 70, height: 1);

  /// 26–32.
  static TextStyle title(double size) => display(size, width: 75, height: 1);

  /// 16–20, UPPERCASE.
  static TextStyle nav(double size) =>
      display(size, width: 80, weight: FontWeight.w800, height: 1);

  static TextStyle data(double size) => TextStyle(
    fontFamily: 'SpaceMono',
    fontFamilyFallback: fallback,
    fontSize: size,
    fontWeight: FontWeight.w700,
    height: 1.3,
  );

  static TextStyle body(double size) => TextStyle(
    fontFamily: 'SpaceMono',
    fontFamilyFallback: fallback,
    fontSize: size,
    height: 1.5,
  );

  static TextStyle label([double size = 11]) => TextStyle(
    fontFamily: 'SpaceMono',
    fontFamilyFallback: fallback,
    fontSize: size,
    fontWeight: FontWeight.w700,
    height: 1.3,
    letterSpacing: 0.4,
  );
}

const double kWireBorder = 2;
const double kWireHairline = 1;

/// Spacing steps.
class WireSpace {
  WireSpace._();
  static const s2 = 2.0,
      s4 = 4.0,
      s8 = 8.0,
      s10 = 10.0,
      s12 = 12.0,
      s14 = 14.0,
      s16 = 16.0,
      s20 = 20.0,
      s24 = 24.0,
      s28 = 28.0,
      s32 = 32.0;
}

/// Layout breakpoints and fixed sizes.
class WireLayout {
  WireLayout._();
  static const desktop = 1024.0;
  static const compact = 600.0;
  static const topBar = 64.0;
  static const sidebar = 220.0;
  static const rail = 72.0;
  static const mobileHeader = 48.0;
  static const actionBar = 56.0;
  static const minHit = 44.0;
}

/// Motion: minimal and mechanical.
class WireMotion {
  WireMotion._();
  static const bars = Duration(milliseconds: 120);
  static const panel = Duration(milliseconds: 180);
  static const panelCurve = Curves.easeOut;
  static const copied = Duration(milliseconds: 1200);
}

ThemeData buildWireTheme(Brightness b, {Color? accent}) {
  final base = b == Brightness.light ? WireColors.light : WireColors.dark;
  final w = base.withSignal(accent ?? WireColors.signalOrange, b);
  final side = BorderSide(color: w.ink, width: kWireBorder);
  const square = RoundedRectangleBorder(borderRadius: BorderRadius.zero);
  final bodyText = WireType.body(13).copyWith(color: w.ink);

  return ThemeData(
    useMaterial3: true,
    brightness: b,
    scaffoldBackgroundColor: w.background,
    canvasColor: w.background,
    fontFamily: 'SpaceMono',
    fontFamilyFallback: WireType.fallback,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    hoverColor: w.signalTint,
    focusColor: Colors.transparent,
    colorScheme: ColorScheme(
      brightness: b,
      primary: w.signal,
      onPrimary: w.onSignal,
      secondary: w.ink,
      onSecondary: w.background,
      error: w.signal,
      onError: w.onSignal,
      surface: w.background,
      onSurface: w.ink,
      outline: w.ink,
      surfaceTint: Colors.transparent,
    ),
    extensions: [w],
    textTheme: TextTheme(
      bodyLarge: bodyText.copyWith(fontSize: 14),
      bodyMedium: bodyText,
      bodySmall: bodyText.copyWith(fontSize: 12),
      labelLarge: WireType.label(12).copyWith(color: w.ink),
      labelMedium: WireType.label().copyWith(color: w.ink),
      labelSmall: WireType.label(10).copyWith(color: w.ink),
      titleLarge: WireType.title(28).copyWith(color: w.ink),
      titleMedium: WireType.nav(18).copyWith(color: w.ink),
      titleSmall: WireType.nav(16).copyWith(color: w.ink),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: w.signal,
      selectionColor: w.signalTint,
      selectionHandleColor: w.signal,
    ),
    dividerTheme: DividerThemeData(
      color: w.ink,
      thickness: kWireHairline,
      space: 0,
    ),
    scrollbarTheme: ScrollbarThemeData(
      thumbColor: WidgetStatePropertyAll(w.ink),
      radius: Radius.zero,
      thickness: const WidgetStatePropertyAll(4),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(color: w.ink),
      textStyle: WireType.label().copyWith(color: w.background),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: w.ink,
      contentTextStyle: WireType.data(13).copyWith(color: w.background),
      shape: square,
      elevation: 0,
      behavior: SnackBarBehavior.floating,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: w.background,
      shape: RoundedRectangleBorder(side: side),
      elevation: 0,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: w.background,
      modalBackgroundColor: w.background,
      shape: RoundedRectangleBorder(side: side),
      elevation: 0,
      modalElevation: 0,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: w.background,
      shape: RoundedRectangleBorder(side: side),
      elevation: 0,
      textStyle: WireType.data(13).copyWith(color: w.ink),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: w.surfaceInput,
      isDense: true,
      hintStyle: WireType.body(13).copyWith(color: w.text3),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: side,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: side,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: w.signal, width: kWireBorder),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: w.signal,
        foregroundColor: w.onSignal,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: side,
        ),
        textStyle: WireType.nav(18),
        minimumSize: const Size(0, 56),
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: w.ink,
        side: side,
        shape: square,
        textStyle: WireType.nav(16),
        minimumSize: const Size(0, 48),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: w.ink,
        shape: square,
        textStyle: WireType.label(12),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? w.signal : w.ink,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? w.ink : Colors.transparent,
      ),
      trackOutlineColor: WidgetStatePropertyAll(w.ink),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: w.signal,
      linearTrackColor: w.mutedRow,
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: _WireSlideTransitionsBuilder(),
        TargetPlatform.iOS: _WireSlideTransitionsBuilder(),
        TargetPlatform.macOS: _WireSlideTransitionsBuilder(),
        TargetPlatform.windows: _WireSlideTransitionsBuilder(),
        TargetPlatform.linux: _WireSlideTransitionsBuilder(),
      },
    ),
  );
}

/// Pushed screens slide in over 180ms easeOut; no fades, no bounces.
class _WireSlideTransitionsBuilder extends PageTransitionsBuilder {
  const _WireSlideTransitionsBuilder();

  @override
  Duration get transitionDuration => WireMotion.panel;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return SlideTransition(
      position: Tween(
        begin: const Offset(1, 0),
        end: Offset.zero,
      ).chain(CurveTween(curve: WireMotion.panelCurve)).animate(animation),
      child: child,
    );
  }
}

extension WireContext on BuildContext {
  WireColors get wire => Theme.of(this).extension<WireColors>()!;
}
