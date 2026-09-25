import 'package:material_ui/material_ui.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/settings_provider.dart';

class FloatingThemeChangeButton extends ConsumerWidget {
  const FloatingThemeChangeButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    final kPrimaryColor = Theme.of(context).primaryColor;
    void handleThemeToggle() {
      if (isDarkTheme) {
        ref.read(settingsProvider.notifier).setThemeMode(ThemeMode.light);
      } else {
        ref.read(settingsProvider.notifier).setThemeMode(ThemeMode.dark);
      }
    }

    return FloatingActionButton(
      onPressed: handleThemeToggle,
      backgroundColor: kPrimaryColor,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 500),
        child: Icon(
          isDarkTheme ? Icons.dark_mode : Icons.light_mode,
          key: Key(
            isDarkTheme.toString(),
          ), // Ensure Flutter animates between different keys
          color: Colors.white,
        ),
        transitionBuilder: (child, animation) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }
}
