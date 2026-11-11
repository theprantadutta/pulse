import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse/core/theme/pulse_theme.dart';
import 'package:pulse/presentations/navigation/pulse_shell.dart';

/// Loads the bundled fonts (Roboto Flex for the app) so renders use real type.
Future<void> loadPulseFonts() async {
  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final f in files) {
      final bytes = File('assets/fonts/$f').readAsBytesSync();
      loader.addFont(Future.value(ByteData.view(bytes.buffer)));
    }
    await loader.load();
  }

  await load('RobotoFlex', ['RobotoFlex-Variable.ttf']);
  await load('Archivo', ['Archivo-Variable.ttf']);
  await load('SpaceMono', ['SpaceMono-Regular.ttf', 'SpaceMono-Bold.ttf']);
  await load('WireGlyphs', ['WireGlyphs.ttf']);
}

/// Pumps [child] at [size] and writes a PNG to `build/renders/<name>.png`.
Future<void> renderToPng(
  WidgetTester tester,
  String name,
  Widget child, {
  Size size = const Size(1280, 800),
  double pixelRatio = 1,
}) async {
  tester.view.physicalSize = size * pixelRatio;
  tester.view.devicePixelRatio = pixelRatio;
  final key = GlobalKey();
  await tester.pumpWidget(RepaintBoundary(key: key, child: child));
  await tester.pump(const Duration(milliseconds: 300));
  await tester.runAsync(() async {
    final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('build/renders/$name.png')..createSync(recursive: true);
    file.writeAsBytesSync(data!.buffer.asUint8List());
  });
}

/// Kit reference sizes (SCREENS.md): phone 390x844, landscape tablet 1280x800.
const kPhone = Size(390, 844);
const kTablet = Size(1280, 800);

/// [child] inside the real app frame ([PulseShell] at [location]) with the
/// Expressive theme, at [size], with phone-like safe-area insets.
Widget pulseTestApp(
  ProviderContainer container,
  Widget child, {
  Brightness brightness = Brightness.dark,
  Size size = kPhone,
  String location = '/ping',
  bool shell = true,
}) => UncontrolledProviderScope(
  container: container,
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: buildPulseTheme(brightness),
    home: MediaQuery(
      data: MediaQueryData(
        size: size,
        padding: size.shortestSide < 600 ? const EdgeInsets.only(top: 40, bottom: 20) : EdgeInsets.zero,
        // Freeze ambient loops so renders are deterministic.
        disableAnimations: true,
      ),
      child: shell ? PulseShell(location: location, child: child) : child,
    ),
  ),
);

/// Renders [child] for every theme x device combination as
/// `build/renders/<name>_<device>_<theme>.png` and returns any exceptions.
Future<List<String>> renderMatrix(
  WidgetTester tester,
  String name,
  ProviderContainer container,
  Widget child, {
  String location = '/ping',
  Map<String, Size> devices = const {'phone': kPhone, 'tablet': kTablet},
}) async {
  final failures = <String>[];
  for (final d in devices.entries) {
    for (final b in Brightness.values) {
      await renderToPng(
        tester,
        '${name}_${d.key}_${b.name}',
        pulseTestApp(container, child, brightness: b, size: d.value, location: location),
        size: d.value,
      );
      final e = tester.takeException();
      if (e != null) failures.add('${d.key}/${b.name}: $e');
    }
  }
  return failures;
}
