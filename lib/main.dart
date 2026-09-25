import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'providers/boot_provider.dart';
import 'providers/settings_provider.dart';
import 'services/desktop/desktop_host.dart';
import 'services/desktop/launch_at_login.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  launchedAtLogin = args.contains(LaunchAtLogin.flag);
  await dotenv.load(fileName: '.env', isOptional: true);
  final prefs = await SharedPreferences.getInstance();
  if (DesktopHost.supported) await DesktopHost.instance.initWindow(hidden: launchedAtLogin);
  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const PulseApp(),
    ),
  );
}
