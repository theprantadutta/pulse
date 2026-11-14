import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';

import '../constants/share_config.dart';
import '../widgets/pulse/pulse.dart';

/// One figure on a shared result card ("Upload 48 Mbps").
class ShareStat {
  const ShareStat(this.label, this.value, {this.unit});
  final String label;
  final String value;
  final String? unit;
}

/// A result someone can share: every tool describes its run with this, and
/// the share sheet turns it into a card image and a plain-text version.
class ShareableResult {
  const ShareableResult({
    required this.tool,
    required this.icon,
    required this.shape,
    required this.tone,
    required this.headline,
    required this.caption,
    this.unit,
    this.stats = const [],
    this.target,
    this.at,
  });

  /// "Speed test", "Ping", "Traceroute"…
  final String tool;
  final PulseIcons icon;
  final PulseShape shape;
  final PulseTone tone;

  /// The big number ("245") and what it is ("Download").
  final String headline;
  final String? unit;
  final String caption;
  final List<ShareStat> stats;

  /// Host, server or network the run was against.
  final String? target;
  final DateTime? at;

  static final _address = RegExp(
    r'\b(?:\d{1,3}\.){3}\d{1,3}\b|\b(?:[0-9a-fA-F]{1,4}:){2,7}[0-9a-fA-F]{0,4}\b|\b(?:[0-9a-fA-F]{1,4}:)+:(?:[0-9a-fA-F]{1,4})?\b',
  );

  /// True when anything on the card is an IP address (the sheet then offers
  /// the "Show IP addresses" switch).
  bool get hasAddresses =>
      _address.hasMatch(target ?? '') || stats.any((s) => _address.hasMatch(s.value)) || _address.hasMatch(headline);

  /// Replaces IP addresses with dots when [hide] is on.
  static String mask(String s, {required bool hide}) => hide ? s.replaceAll(_address, '•••') : s;

  String text({required bool hideAddresses}) {
    String m(String s) => mask(s, hide: hideAddresses);
    return [
      '$tool${target == null ? '' : ' · ${m(target!)}'}',
      '$caption: ${m(headline)}${unit == null ? '' : ' $unit'}',
      for (final s in stats) '${s.label}: ${m(s.value)}${s.unit == null ? '' : ' ${s.unit}'}',
      if (at != null) DateFormat('MMM d, y · HH:mm').format(at!),
      '',
      PulseShareConfig.resultFooter,
    ].join('\n');
  }
}

Rect? _origin(BuildContext context) {
  final box = context.findRenderObject();
  if (box is! RenderBox || !box.hasSize) return null;
  return box.localToGlobal(Offset.zero) & box.size;
}

/// "Share Pulse": the app link with a one-line pitch. Thanks the user only
/// when the share actually went out (not when they backed out of the sheet).
Future<void> shareApp(BuildContext context) async {
  final result = await SharePlus.instance.share(
    ShareParams(
      title: 'Share Pulse',
      text: PulseShareConfig.shareAppText,
      subject: PulseShareConfig.appName,
      sharePositionOrigin: _origin(context),
    ),
  );
  if (result.status == ShareResultStatus.success && context.mounted) {
    showPulseToast(context, 'Thanks for sharing Pulse!', icon: PulseIcons.heart);
  }
}

/// Opens the share preview for [result]: the card as it will look, a switch to
/// show or hide IP addresses, then share as image, share as text, or copy.
Future<void> showShareResult(BuildContext context, ShareableResult result) => showModalBottomSheet<void>(
  context: context,
  useRootNavigator: true,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => _ShareSheet(result: result),
);

class _ShareSheet extends StatefulWidget {
  const _ShareSheet({required this.result});
  final ShareableResult result;

  @override
  State<_ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends State<_ShareSheet> {
  final _card = GlobalKey();
  bool _hide = PulseShareConfig.hideAddressesByDefault;
  bool _busy = false;

  ShareableResult get r => widget.result;

  Future<void> _shareImage(BuildContext buttonContext) async {
    setState(() => _busy = true);
    try {
      final boundary = _card.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (png == null || !buttonContext.mounted) return;
      final name = 'pulse-${r.tool.toLowerCase().replaceAll(RegExp('[^a-z0-9]+'), '-')}.png';
      final file = XFile.fromData(png.buffer.asUint8List(), mimeType: 'image/png', name: name);
      await SharePlus.instance.share(
        ShareParams(
          title: 'Share ${r.tool.toLowerCase()} result',
          files: [file],
          fileNameOverrides: [name],
          // Android shows the card itself as the share sheet's preview.
          previewThumbnail: file,
          text: r.text(hideAddresses: _hide),
          subject: 'Pulse · ${r.tool}',
          sharePositionOrigin: _origin(buttonContext),
        ),
      );
    } on Object {
      if (mounted) showPulseToast(context, "Couldn't create the image. Share it as text instead.");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _shareText(BuildContext buttonContext) => SharePlus.instance.share(
    ShareParams(
      title: 'Share ${r.tool.toLowerCase()} result',
      text: r.text(hideAddresses: _hide),
      subject: 'Pulse · ${r.tool}',
      sharePositionOrigin: _origin(buttonContext),
    ),
  );

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: r.text(hideAddresses: _hide)));
    if (mounted) showPulseToast(context, 'Result copied', icon: PulseIcons.copy);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(header: true, child: Text('Share ${r.tool.toLowerCase()}', style: context.type.headlineSmall)),
          const SizedBox(height: 4),
          Text('This is what people will see.', style: context.type.bodyMedium!.copyWith(color: c.onSurfaceVariant)),
          const SizedBox(height: 16),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: RepaintBoundary(
                key: _card,
                child: PulseResultCard(result: r, hideAddresses: _hide),
              ),
            ),
          ),
          if (r.hasAddresses) ...[
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              title: const Text('Show IP addresses'),
              subtitle: const Text('Off keeps your addresses private'),
              value: !_hide,
              onChanged: (v) => setState(() => _hide = !v),
            ),
          ],
          const SizedBox(height: 16),
          Builder(
            builder: (b) => PulseButton(
              label: _busy ? 'Preparing…' : 'Share image',
              icon: PulseIcons.share,
              size: PulseButtonSize.large,
              expand: true,
              onPressed: _busy ? null : () => _shareImage(b),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Builder(
                  builder: (b) => PulseButton(
                    label: 'Share text',
                    icon: PulseIcons.export,
                    style: PulseButtonStyle.tonal,
                    expand: true,
                    onPressed: () => _shareText(b),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: PulseButton(
                  label: 'Copy',
                  icon: PulseIcons.copy,
                  style: PulseButtonStyle.outlined,
                  expand: true,
                  onPressed: _copy,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The shareable card: brand surface, the tool's badge, the big number, a few
/// stats and the Pulse footer. Also the image that gets shared.
class PulseResultCard extends StatelessWidget {
  const PulseResultCard({super.key, required this.result, this.hideAddresses = true});

  final ShareableResult result;
  final bool hideAddresses;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final r = result;
    String m(String s) => ShareableResult.mask(s, hide: hideAddresses);
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: ColoredBox(
        color: c.surfaceContainer,
        child: Stack(
          children: [
            // Oversized brand shape as a soft backdrop.
            Positioned(
              right: -70,
              top: -60,
              child: Opacity(
                opacity: .16,
                child: PulseShapeBox(shape: r.shape, color: r.tone.fill(context), size: 240),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      PulseShapeBadge(shape: r.shape, tone: r.tone, icon: r.icon, size: 44),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(r.tool, style: context.type.titleMedium),
                            if (r.at != null)
                              Text(
                                DateFormat('MMM d, y · HH:mm').format(r.at!),
                                style: context.type.bodySmall!.copyWith(color: c.onSurfaceVariant),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Text(r.caption, style: context.type.labelLarge!.copyWith(color: c.onSurfaceVariant)),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          m(r.headline),
                          style: pulseText(
                            80,
                            900,
                            wdth: 125,
                            height: 1.05,
                            tracking: -.03,
                          ).copyWith(color: c.onSurface),
                        ),
                        if (r.unit != null) ...[
                          const SizedBox(width: 8),
                          Text(r.unit!, style: pulseText(24, 800).copyWith(color: c.primary)),
                        ],
                      ],
                    ),
                  ),
                  if (r.target != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      m(r.target!),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.type.bodyMedium!.copyWith(color: c.onSurfaceVariant),
                    ),
                  ],
                  if (r.stats.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final s in r.stats)
                          Container(
                            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                            decoration: BoxDecoration(
                              color: c.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(s.label, style: context.type.labelSmall!.copyWith(color: c.onSurfaceVariant)),
                                Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(text: m(s.value), style: pulseNumber(18)),
                                      if (s.unit != null)
                                        TextSpan(
                                          text: ' ${s.unit}',
                                          style: pulseText(12, 700).copyWith(color: c.onSurfaceVariant),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      const PulseLogo(size: 26, animated: false),
                      const SizedBox(width: 8),
                      Text('Pulse', style: pulseText(16, 800).copyWith(color: c.onSurface)),
                      const Spacer(),
                      Text(
                        PulseShareConfig.websiteUrl.replaceFirst('https://', ''),
                        style: context.type.labelMedium!.copyWith(color: c.onSurfaceVariant),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
