import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/widgets/pulse/pulse.dart';
import '../../../providers/speed_provider.dart';
import '../../../services/net/speed_test.dart';

/// "9.4", "212".
String fmtMbps(double? v) => v == null
    ? '—'
    : v >= 100
    ? v.toStringAsFixed(0)
    : v.toStringAsFixed(1);

/// The figure shown while a phase is running: whole Mbps (one decimal under
/// 10), so the odometer doesn't spin a tenths digit four times a second.
String fmtLiveMbps(double? v) => v == null ? '—' : (v >= 10 ? v.toStringAsFixed(0) : v.toStringAsFixed(1));

/// Gauge position on the kit's log scale: 1–500 Mbps → 0–1.
double speedGaugeValue(double? mbps) => (math.log(math.max(mbps ?? 0, 1)) / math.log(500)).clamp(0, 1).toDouble();

/// Short server label: "Cloudflare · DAC", "Hetzner · Falkenstein".
String serverLabel(SpeedState s) {
  if (!s.hasServer) return s.selecting ? 'Finding server…' : 'Choose server';
  if (s.server.isCloudflare) return 'Cloudflare${s.colo == null ? '' : ' · ${s.colo}'}';
  return '${s.server.name} · ${s.server.location.split(',').first}';
}

/// "Today 16:34", "Yesterday 22:41", "Sep 23 16:44".
String fmtDay(DateTime t, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final diff = DateTime(n.year, n.month, n.day).difference(DateTime(t.year, t.month, t.day)).inDays;
  final hm = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  if (diff == 0) return 'Today $hm';
  if (diff == 1) return 'Yesterday $hm';
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${months[t.month - 1]} ${t.day} $hm';
}

/// A dashed outline that follows [path] (the "pending" upload tile and card).
class DashedOutline extends StatelessWidget {
  const DashedOutline({super.key, required this.path, required this.child, this.color, this.strokeWidth = 2});

  /// Outline inside the widget's bounds.
  final Path Function(Rect rect) path;
  final Widget child;
  final Color? color;
  final double strokeWidth;

  /// Arch outline from the shape family.
  static Path Function(Rect) shape(PulseShape s) =>
      (rect) => pulseShapePath(s, rect);

  /// Rounded rectangle outline.
  static Path Function(Rect) rounded(double radius) =>
      (rect) => Path()..addRRect(RRect.fromRectAndRadius(rect.deflate(1), Radius.circular(radius)));

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _DashedPathPainter(path, color ?? context.colors.outlineVariant, strokeWidth), child: child);
}

class _DashedPathPainter extends CustomPainter {
  _DashedPathPainter(this.path, this.color, this.strokeWidth);
  final Path Function(Rect) path;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    final outline = path(Offset.zero & size);
    const dash = 7.0, gap = 6.0;
    for (final m in outline.computeMetrics()) {
      for (var d = 0.0; d < m.length; d += dash + gap) {
        canvas.drawPath(m.extractPath(d, math.min(d + dash, m.length)), p);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedPathPainter old) => old.color != color || old.strokeWidth != strokeWidth;
}

/// Bottom sheet listing the download servers. Uploads always go to Cloudflare.
Future<void> showSpeedServerSheet(BuildContext context, WidgetRef ref) async {
  final picked = await showModalBottomSheet<Object>(
    useRootNavigator: true,
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => const _ServerSheet(),
  );
  final n = ref.read(speedProvider.notifier);
  if (picked is SpeedServer) {
    n.choose(picked);
  } else if (picked == _auto) {
    await n.autoSelect();
  }
}

const _auto = 'auto';

class _ServerSheet extends ConsumerWidget {
  const _ServerSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(speedProvider);
    final n = ref.read(speedProvider.notifier);
    final c = context.colors;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .8),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
              child: Text('Server', style: context.type.headlineMedium),
            ),
            PulseSegmentedList(
              animate: false,
              children: [
                PulseListItem(
                  title: 'Auto',
                  subtitle: 'Lowest latency right now',
                  leading: PulseContainerBadge(
                    shape: PulseShape.cookie9,
                    icon: PulseIcons.auto,
                    color: c.primaryContainer,
                    onColor: c.onPrimaryContainer,
                  ),
                  selected: s.autoSelected,
                  onTap: s.running ? null : () => Navigator.of(context).pop(_auto),
                ),
                for (final server in kSpeedServers)
                  PulseListItem(
                    title: server.isCloudflare ? 'Cloudflare' : '${server.name} · ${server.location}',
                    subtitle: [
                      if (server.isCloudflare) 'Nearest edge · anycast',
                      if (n.distanceTo(server) case final d?) '${d.round()} km',
                      if (!server.isCloudflare) 'Download only',
                    ].join(' · '),
                    leading: server.isCloudflare
                        ? PulseContainerBadge(
                            shape: PulseShape.arch,
                            icon: PulseIcons.cloud,
                            color: c.secondaryContainer,
                            onColor: c.onSecondaryContainer,
                          )
                        : PulseContainerBadge(
                            shape: PulseShape.circle,
                            icon: PulseIcons.server,
                            color: c.tertiaryContainer,
                            onColor: c.onTertiaryContainer,
                          ),
                    selected: !s.autoSelected && s.server.id == server.id,
                    onTap: s.running ? null : () => Navigator.of(context).pop(server),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
              child: Text(
                s.running
                    ? 'Cancel the running test to switch servers.'
                    : 'Uploads always go to Cloudflare. Hetzner servers only serve downloads.',
                style: context.type.bodySmall!.copyWith(color: c.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
