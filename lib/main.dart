import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'providers/boot_provider.dart';
import 'providers/settings_provider.dart';
import 'services/desktop/desktop_host.dart';
import 'services/desktop/launch_at_login.dart';

void main(List<String> args) async {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  // Keep the OS splash up until SplashScreen paints the same logo (it calls
  // FlutterNativeSplash.remove after its first frame). Only mobile has a
  // native splash; on desktop the runner shows its window on the first frame
  // the engine receives, so deferring it would keep the window invisible.
  if (Platform.isAndroid || Platform.isIOS) FlutterNativeSplash.preserve(widgetsBinding: binding);
  launchedAtLogin = args.contains(LaunchAtLogin.flag);
  await dotenv.load(fileName: '.env', isOptional: true);
  final prefs = await SharedPreferences.getInstance();
  await _lockPhonesToPortrait();
  if (DesktopHost.supported) DesktopHost.instance.initWindow(hidden: launchedAtLogin);
  runApp(ProviderScope(overrides: [sharedPreferencesProvider.overrideWithValue(prefs)], child: const PulseApp()));
}

/// Phones stay portrait: in landscape the mobile frame leaves ~100 dp for
/// content. Tablets (shortest side ≥ 600 dp) rotate freely and get the rail
/// frame in landscape.
Future<void> _lockPhonesToPortrait() async {
  if (!Platform.isAndroid && !Platform.isIOS) return;
  final display = WidgetsBinding.instance.platformDispatcher.displays.first;
  final shortest = display.size.shortestSide / display.devicePixelRatio;
  if (shortest > 0 && shortest < 600) {
    await SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);
  }
}
