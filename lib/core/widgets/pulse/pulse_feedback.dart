import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../theme/pulse_shapes.dart';
import '../../theme/pulse_theme.dart';
import 'pulse_controls.dart';
import 'pulse_data.dart';
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

/// Opens a web link only after the user agrees: a dialog names the site and
/// shows the full address, with Open, Copy link and Cancel. Every external
/// http(s) link in the app goes through here.
Future<void> openExternalLink(BuildContext context, String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  final choice = await showDialog<_LinkChoice>(
    context: context,
    builder: (context) => _OpenLinkDialog(uri: uri),
  );
  if (choice == null || !context.mounted) return;
  if (choice == _LinkChoice.copy) {
    await Clipboard.setData(ClipboardData(text: url));
    if (context.mounted) showPulseToast(context, 'Link copied', icon: PulseIcons.copy);
    return;
  }
  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) showPulseToast(context, "Couldn't open a browser", icon: PulseIcons.globe);
}

enum _LinkChoice { open, copy }

class _OpenLinkDialog extends StatelessWidget {
  const _OpenLinkDialog({required this.uri});
  final Uri uri;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final address = uri.toString().replaceFirst(RegExp('^https?://'), '');
    return AlertDialog(
      icon: const PulseShapeBadge(
        shape: PulseShape.cookie9,
        tone: PulseTone.lavender,
        icon: PulseIcons.globe,
        size: 56,
      ),
      title: const Text('Open in your browser?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            uri.host.replaceFirst('www.', ''),
            textAlign: TextAlign.center,
            style: context.type.titleMedium!.copyWith(color: c.onSurface),
          ),
          const SizedBox(height: 6),
          Text(
            address,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: context.type.bodySmall!.copyWith(color: c.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          Text(
            'This leaves Pulse and opens the page in your browser.',
            textAlign: TextAlign.center,
            style: context.type.bodyMedium!.copyWith(color: c.onSurfaceVariant),
          ),
        ],
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        PulseIconButton(
          icon: PulseIcons.copy,
          tooltip: 'Copy link',
          onPressed: () => Navigator.pop(context, _LinkChoice.copy),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PulseButton(label: 'Cancel', style: PulseButtonStyle.text, onPressed: () => Navigator.pop(context)),
            const SizedBox(width: 8),
            PulseButton(
              label: 'Open',
              icon: PulseIcons.globe,
              onPressed: () => Navigator.pop(context, _LinkChoice.open),
            ),
          ],
        ),
      ],
    );
  }
}
