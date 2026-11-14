import 'package:material_ui/material_ui.dart';

import '../../theme/pulse_theme.dart';
import 'pulse_icons.dart';

/// One short, floating message (the theme's inverse-surface snackbar) with an
/// optional icon. Replaces the current one so taps never queue a backlog.
void showPulseToast(BuildContext context, String message, {PulseIcons? icon, Duration? duration}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  final c = context.colors;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        duration: duration ?? const Duration(seconds: 3),
        content: Row(
          children: [
            if (icon != null) ...[PulseIcon(icon, size: 20, color: c.inversePrimary), const SizedBox(width: 12)],
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
}
