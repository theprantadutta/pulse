// Pulse — "Expressive" theme (Material 3 Expressive, plum / pink / lime).
//
// Drop into lib/theme/pulse_theme.dart.
// Requires Flutter >= 3.27 (fixed color roles on ColorScheme, CardThemeData,
// WidgetStateProperty). Register the font in pubspec.yaml as family "RobotoFlex"
// (see README.md, "Fonts").
//
// Usage:
//   MaterialApp(
//     theme: buildPulseTheme(Brightness.light),
//     darkTheme: buildPulseTheme(Brightness.dark),
//     themeMode: ThemeMode.system,
//   );
//   // anywhere:  context.pulse.latencyColor(ms), context.colors.primary

import 'dart:ui' show FontFeature, FontVariation;

import 'package:flutter/material.dart';

/// Brand colors that never change between light and dark.
abstract final class PulseBrand {
  static const pink = Color(0xFFFFAFD0); // primaryFixedDim — hero cookie, FAB
  static const pinkSoft = Color(0xFFFFD9E6); // primaryFixed
  static const onPink = Color(0xFF3B0720); // onPrimaryFixed
  static const lavender = Color(0xFFDDBCFF); // secondaryFixedDim
  static const onLavender = Color(0xFF25074A);
  static const lime = Color(0xFFCDEB74); // tertiaryFixedDim
  static const onLime = Color(0xFF141F00);
  static const logoTile = Color(0xFF4A1D3B); // app icon background
  static const heartbeat = Color(0xFF4A0F2C); // logo ECG line
}

const String pulseFontFamily = 'RobotoFlex';

// ---------------------------------------------------------------------------
// Color schemes
// ---------------------------------------------------------------------------

const ColorScheme pulseDarkScheme = ColorScheme(
  brightness: Brightness.dark,
  primary: Color(0xFFFFAFD0),
  onPrimary: Color(0xFF5A1335),
  primaryContainer: Color(0xFF7A2950),
  onPrimaryContainer: Color(0xFFFFD9E6),
  primaryFixed: Color(0xFFFFD9E6),
  primaryFixedDim: Color(0xFFFFAFD0),
  onPrimaryFixed: Color(0xFF3B0720),
  onPrimaryFixedVariant: Color(0xFF7A2950),
  secondary: Color(0xFFDDBCFF),
  onSecondary: Color(0xFF3A1F57),
  secondaryContainer: Color(0xFF4B3466),
  onSecondaryContainer: Color(0xFFF0DBFF),
  secondaryFixed: Color(0xFFF0DBFF),
  secondaryFixedDim: Color(0xFFDDBCFF),
  onSecondaryFixed: Color(0xFF25074A),
  onSecondaryFixedVariant: Color(0xFF4B3466),
  tertiary: Color(0xFFCDEB74),
  onTertiary: Color(0xFF2B3700),
  tertiaryContainer: Color(0xFF3F5100),
  onTertiaryContainer: Color(0xFFE0F98A),
  tertiaryFixed: Color(0xFFE0F98A),
  tertiaryFixedDim: Color(0xFFCDEB74),
  onTertiaryFixed: Color(0xFF141F00),
  onTertiaryFixedVariant: Color(0xFF3F5100),
  error: Color(0xFFFFB4AB),
  onError: Color(0xFF690005),
  errorContainer: Color(0xFF93000A),
  onErrorContainer: Color(0xFFFFDAD6),
  surface: Color(0xFF19121D),
  onSurface: Color(0xFFF3E5F4),
  onSurfaceVariant: Color(0xFFD3C2D6),
  surfaceDim: Color(0xFF19121D),
  surfaceBright: Color(0xFF403644),
  surfaceContainerLowest: Color(0xFF130D17),
  surfaceContainerLow: Color(0xFF1F1724),
  surfaceContainer: Color(0xFF241B29),
  surfaceContainerHigh: Color(0xFF2F2535),
  surfaceContainerHighest: Color(0xFF3A2F40),
  outline: Color(0xFF9C8BA0),
  outlineVariant: Color(0xFF5E4F63),
  shadow: Color(0xFF000000),
  scrim: Color(0xFF000000),
  inverseSurface: Color(0xFFF3E5F4),
  onInverseSurface: Color(0xFF362D3A),
  inversePrimary: Color(0xFF8E3A60),
  surfaceTint: Color(0x00000000), // tonal surfaces only, no tint overlay
);

const ColorScheme pulseLightScheme = ColorScheme(
  brightness: Brightness.light,
  primary: Color(0xFF8E3A60),
  onPrimary: Color(0xFFFFFFFF),
  primaryContainer: Color(0xFFFFD9E6),
  onPrimaryContainer: Color(0xFF3B0720),
  primaryFixed: Color(0xFFFFD9E6),
  primaryFixedDim: Color(0xFFFFAFD0),
  onPrimaryFixed: Color(0xFF3B0720),
  onPrimaryFixedVariant: Color(0xFF7A2950),
  secondary: Color(0xFF6B4F8A),
  onSecondary: Color(0xFFFFFFFF),
  secondaryContainer: Color(0xFFF0DBFF),
  onSecondaryContainer: Color(0xFF25074A),
  secondaryFixed: Color(0xFFF0DBFF),
  secondaryFixedDim: Color(0xFFDDBCFF),
  onSecondaryFixed: Color(0xFF25074A),
  onSecondaryFixedVariant: Color(0xFF4B3466),
  tertiary: Color(0xFF4A6200),
  onTertiary: Color(0xFFFFFFFF),
  tertiaryContainer: Color(0xFFCDEB74),
  onTertiaryContainer: Color(0xFF141F00),
  tertiaryFixed: Color(0xFFE0F98A),
  tertiaryFixedDim: Color(0xFFCDEB74),
  onTertiaryFixed: Color(0xFF141F00),
  onTertiaryFixedVariant: Color(0xFF3F5100),
  error: Color(0xFFBA1A1A),
  onError: Color(0xFFFFFFFF),
  errorContainer: Color(0xFFFFDAD6),
  onErrorContainer: Color(0xFF410002),
  surface: Color(0xFFFFF7FA),
  onSurface: Color(0xFF21181E),
  onSurfaceVariant: Color(0xFF524349),
  surfaceDim: Color(0xFFE4D7DD),
  surfaceBright: Color(0xFFFFF7FA),
  surfaceContainerLowest: Color(0xFFFFFFFF),
  surfaceContainerLow: Color(0xFFFCF0F5),
  surfaceContainer: Color(0xFFF7EAF0),
  surfaceContainerHigh: Color(0xFFF1E4EA),
  surfaceContainerHighest: Color(0xFFEBDEE4),
  outline: Color(0xFF847379),
  outlineVariant: Color(0xFFD6C2CA),
  shadow: Color(0xFF000000),
  scrim: Color(0xFF000000),
  inverseSurface: Color(0xFF362D33),
  onInverseSurface: Color(0xFFFCEEF4),
  inversePrimary: Color(0xFFFFAFD0),
  surfaceTint: Color(0x00000000),
);

// ---------------------------------------------------------------------------
// Extra semantic tokens
// ---------------------------------------------------------------------------

@immutable
class PulseTokens extends ThemeExtension<PulseTokens> {
  const PulseTokens({
    required this.latFast,
    required this.latMedium,
    required this.latSlow,
    required this.latTimeout,
    required this.mapSea,
    required this.mapLand,
    required this.mapBorder,
    required this.mapRoute,
  });

  /// Latency semantics for small marks and text (dots, bars, values).
  final Color latFast; // < 10 ms
  final Color latMedium; // 10–40 ms
  final Color latSlow; // > 40 ms, and lost packets
  final Color latTimeout; // no reply
  final Color mapSea;
  final Color mapLand;
  final Color mapBorder;
  final Color mapRoute;

  static const double fastBelowMs = 10;
  static const double mediumUpToMs = 40;

  Color latencyColor(double? ms) {
    if (ms == null) return latTimeout;
    if (ms < fastBelowMs) return latFast;
    if (ms <= mediumUpToMs) return latMedium;
    return latSlow;
  }

  static const dark = PulseTokens(
    latFast: Color(0xFFCDEB74),
    latMedium: Color(0xFFDDBCFF),
    latSlow: Color(0xFFFFAFD0),
    latTimeout: Color(0xFF9C8BA0),
    mapSea: Color(0xFF1F1724),
    mapLand: Color(0xFF3A2F40),
    mapBorder: Color(0xFF5E4F63),
    mapRoute: Color(0xFFFFAFD0),
  );

  static const light = PulseTokens(
    latFast: Color(0xFF4F6B00),
    latMedium: Color(0xFF72519C),
    latSlow: Color(0xFFB0306A),
    latTimeout: Color(0xFF847379),
    mapSea: Color(0xFFFCF0F5),
    mapLand: Color(0xFFEBDEE4),
    mapBorder: Color(0xFFD6C2CA),
    mapRoute: Color(0xFF8E3A60),
  );

  @override
  PulseTokens copyWith({
    Color? latFast,
    Color? latMedium,
    Color? latSlow,
    Color? latTimeout,
    Color? mapSea,
    Color? mapLand,
    Color? mapBorder,
    Color? mapRoute,
  }) {
    return PulseTokens(
      latFast: latFast ?? this.latFast,
      latMedium: latMedium ?? this.latMedium,
      latSlow: latSlow ?? this.latSlow,
      latTimeout: latTimeout ?? this.latTimeout,
      mapSea: mapSea ?? this.mapSea,
      mapLand: mapLand ?? this.mapLand,
      mapBorder: mapBorder ?? this.mapBorder,
      mapRoute: mapRoute ?? this.mapRoute,
    );
  }

  @override
  PulseTokens lerp(ThemeExtension<PulseTokens>? other, double t) {
    if (other is! PulseTokens) return this;
    return PulseTokens(
      latFast: Color.lerp(latFast, other.latFast, t)!,
      latMedium: Color.lerp(latMedium, other.latMedium, t)!,
      latSlow: Color.lerp(latSlow, other.latSlow, t)!,
      latTimeout: Color.lerp(latTimeout, other.latTimeout, t)!,
      mapSea: Color.lerp(mapSea, other.mapSea, t)!,
      mapLand: Color.lerp(mapLand, other.mapLand, t)!,
      mapBorder: Color.lerp(mapBorder, other.mapBorder, t)!,
      mapRoute: Color.lerp(mapRoute, other.mapRoute, t)!,
    );
  }
}

extension PulseThemeContext on BuildContext {
  PulseTokens get pulse => Theme.of(this).extension<PulseTokens>()!;
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get type => Theme.of(this).textTheme;
}

// ---------------------------------------------------------------------------
// Typography — Roboto Flex variable font
// ---------------------------------------------------------------------------

FontWeight _nearestWeight(double w) => FontWeight.values[(w.clamp(100, 900) / 100).round() - 1];

/// Build a Roboto Flex style. [wdth] is the width axis (25–151, 100 = normal).
TextStyle pulseText(
  double size,
  double weight, {
  double wdth = 100,
  double height = 1.3,
  double tracking = 0, // in em
}) {
  return TextStyle(
    fontFamily: pulseFontFamily,
    fontSize: size,
    height: height,
    letterSpacing: tracking * size,
    fontWeight: _nearestWeight(weight),
    fontVariations: <FontVariation>[FontVariation('wght', weight), FontVariation('wdth', wdth)],
    fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
  );
}

final TextTheme pulseTextTheme = TextTheme(
  displayLarge: pulseText(104, 900, wdth: 120, height: 0.95, tracking: -0.04), // hero latency number
  displayMedium: pulseText(76, 900, wdth: 125, height: 0.9, tracking: -0.04), // summary numbers
  displaySmall: pulseText(56, 900, wdth: 120, height: 1.0, tracking: -0.03),
  headlineLarge: pulseText(40, 800, wdth: 125, height: 1.05, tracking: -0.02), // top-level titles
  headlineMedium: pulseText(28, 800, wdth: 115, height: 1.1, tracking: -0.01), // tablet pane titles
  headlineSmall: pulseText(24, 800, wdth: 110, height: 1.15),
  titleLarge: pulseText(22, 700, height: 1.2),
  titleMedium: pulseText(16, 600, height: 1.3),
  titleSmall: pulseText(14, 600, height: 1.3),
  bodyLarge: pulseText(16, 400, height: 1.45),
  bodyMedium: pulseText(14, 400, height: 1.4),
  bodySmall: pulseText(13, 400, height: 1.35),
  labelLarge: pulseText(14, 700, height: 1.2),
  labelMedium: pulseText(12, 600, height: 1.3),
  labelSmall: pulseText(11, 700, height: 1.3, tracking: 0.1),
);

/// Numbers in lists, stats and chips (20 / 800 / wdth 110).
TextStyle pulseNumber([double size = 20]) => pulseText(size, 800, wdth: 110, height: 1.1);

// ---------------------------------------------------------------------------
// ThemeData
// ---------------------------------------------------------------------------

ThemeData buildPulseTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final s = dark ? pulseDarkScheme : pulseLightScheme;
  final t = pulseTextTheme.apply(bodyColor: s.onSurface, displayColor: s.onSurface);

  WidgetStateProperty<T> sel<T>(T on, T off) =>
      WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? on : off);

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: s,
    scaffoldBackgroundColor: s.surface,
    fontFamily: pulseFontFamily,
    textTheme: t,
    extensions: <ThemeExtension<dynamic>>[dark ? PulseTokens.dark : PulseTokens.light],
    visualDensity: VisualDensity.standard,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    appBarTheme: AppBarTheme(
      backgroundColor: s.surface,
      foregroundColor: s.onSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: t.titleLarge,
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 80,
      elevation: 0,
      backgroundColor: s.surfaceContainer,
      indicatorColor: s.secondaryContainer,
      indicatorShape: const StadiumBorder(),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      labelTextStyle: sel(
        t.labelMedium!.copyWith(fontWeight: FontWeight.w700, color: s.onSurface),
        t.labelMedium!.copyWith(fontWeight: FontWeight.w500, color: s.onSurfaceVariant),
      ),
      iconTheme: sel(
        IconThemeData(size: 22, color: s.onSecondaryContainer),
        IconThemeData(size: 22, color: s.onSurfaceVariant),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: s.surface,
      indicatorColor: s.secondaryContainer,
      indicatorShape: const StadiumBorder(),
      minWidth: 96,
      labelType: NavigationRailLabelType.all,
      groupAlignment: -1,
      selectedIconTheme: IconThemeData(size: 22, color: s.onSecondaryContainer),
      unselectedIconTheme: IconThemeData(size: 22, color: s.onSurfaceVariant),
      selectedLabelTextStyle: t.labelMedium!.copyWith(fontWeight: FontWeight.w700, color: s.onSurface),
      unselectedLabelTextStyle: t.labelMedium!.copyWith(fontWeight: FontWeight.w500, color: s.onSurfaceVariant),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        shape: const StadiumBorder(),
        textStyle: t.labelLarge,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        shape: const StadiumBorder(),
        side: BorderSide(color: s.outlineVariant),
        foregroundColor: s.onSurface,
        textStyle: t.labelLarge,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(minimumSize: const Size(48, 40), shape: const StadiumBorder(), textStyle: t.labelLarge),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(minimumSize: const Size(48, 48), foregroundColor: s.onSurfaceVariant),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: s.primaryFixedDim,
      foregroundColor: s.onPrimaryFixed,
      elevation: 3,
      focusElevation: 3,
      hoverElevation: 4,
      highlightElevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      extendedSizeConstraints: const BoxConstraints(minHeight: 60),
      extendedPadding: const EdgeInsets.only(left: 18, right: 22),
      extendedTextStyle: t.titleMedium!.copyWith(fontWeight: FontWeight.w800),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      side: BorderSide(color: s.outlineVariant),
      backgroundColor: Colors.transparent,
      selectedColor: s.secondaryContainer,
      checkmarkColor: s.onSecondaryContainer,
      labelStyle: t.bodyMedium!.copyWith(fontWeight: FontWeight.w500, color: s.onSurfaceVariant),
      secondaryLabelStyle: t.bodyMedium!.copyWith(fontWeight: FontWeight.w600, color: s.onSecondaryContainer),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      showCheckmark: true,
    ),
    cardTheme: CardThemeData(
      color: s.surfaceContainer,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      clipBehavior: Clip.antiAlias,
    ),
    listTileTheme: ListTileThemeData(
      tileColor: s.surfaceContainer,
      selectedTileColor: s.secondaryContainer,
      selectedColor: s.onSecondaryContainer,
      iconColor: s.onSurfaceVariant,
      minVerticalPadding: 8,
      contentPadding: const EdgeInsets.only(left: 12, right: 16),
      titleTextStyle: t.titleMedium,
      subtitleTextStyle: t.bodySmall!.copyWith(color: s.onSurfaceVariant),
    ),
    searchBarTheme: SearchBarThemeData(
      backgroundColor: WidgetStatePropertyAll(s.surfaceContainerHigh),
      elevation: const WidgetStatePropertyAll(0),
      shape: const WidgetStatePropertyAll(StadiumBorder()),
      constraints: const BoxConstraints(minHeight: 56),
      padding: const WidgetStatePropertyAll(EdgeInsets.only(left: 16, right: 20)),
      textStyle: WidgetStatePropertyAll(t.titleMedium!.copyWith(fontSize: 17)),
      hintStyle: WidgetStatePropertyAll(t.titleMedium!.copyWith(fontSize: 17, color: s.onSurfaceVariant)),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
        backgroundColor: sel<Color?>(s.primaryFixedDim, s.surfaceContainerHigh),
        foregroundColor: sel<Color?>(s.onPrimaryFixed, s.onSurfaceVariant),
        side: const WidgetStatePropertyAll(BorderSide.none),
        textStyle: WidgetStatePropertyAll(t.labelLarge),
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: s.primary,
      linearTrackColor: s.secondaryContainer,
      circularTrackColor: s.surfaceContainerHigh,
    ),
    dividerTheme: DividerThemeData(color: s.outlineVariant, thickness: 1, space: 1),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: s.inverseSurface,
      contentTextStyle: t.bodyMedium!.copyWith(color: s.onInverseSurface),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: s.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      showDragHandle: true,
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: <TargetPlatform, PageTransitionsBuilder>{
        TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
  );
}

/// Corner radii for the M3 Expressive segmented list: 24 on the group's outer
/// corners, 6 between items, 3 px gaps (see DESIGN_SYSTEM.md, "Segmented list").
BorderRadius segmentedRadius(int index, int count, {double outer = 24, double inner = 6}) {
  final first = index == 0, last = index == count - 1;
  return BorderRadius.vertical(
    top: Radius.circular(first ? outer : inner),
    bottom: Radius.circular(last ? outer : inner),
  );
}

/// Same idea for a horizontal stat row / connected button group.
BorderRadius connectedRadius(int index, int count, {double outer = 20, double inner = 6}) {
  final first = index == 0, last = index == count - 1;
  return BorderRadius.horizontal(
    left: Radius.circular(first ? outer : inner),
    right: Radius.circular(last ? outer : inner),
  );
}
