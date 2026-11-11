import 'dart:math' as math;

import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/widgets/pulse/pulse.dart';
import '../../../providers/monitor_provider.dart';

// ---------------------------------------------------------------------------
// Labels
// ---------------------------------------------------------------------------

/// "Running · 6 targets", "Paused", "Checking now…".
String monitorStatusLabel(MonitorRunState run, int targets) {
  final n = '$targets target${targets == 1 ? '' : 's'}';
  if (run.cycling) return 'Checking now · $n';
  return switch (run.mode) {
    MonitorMode.tray => 'Running in tray · $n',
    MonitorMode.service => 'Running in background · $n',
    MonitorMode.app => 'Running · $n',
    MonitorMode.paused => 'Paused · $n',
    MonitorMode.idle => 'Idle · $n',
  };
}

/// Short label for the status strip on narrow phones.
String monitorStatusShort(MonitorRunState run, int targets) {
  final n = '$targets target${targets == 1 ? '' : 's'}';
  if (run.cycling) return 'Checking · $n';
  return switch (run.mode) {
    MonitorMode.paused => 'Paused · $n',
    MonitorMode.idle => 'Idle · $n',
    _ => 'Running · $n',
  };
}

String rangeLabel(MonitorRange r) => switch (r) {
  MonitorRange.day => '24 h',
  MonitorRange.week => '7 d',
  MonitorRange.month => '30 d',
};

String rangeTitle(MonitorRange r) => switch (r) {
  MonitorRange.day => '24h',
  MonitorRange.week => '7d',
  MonitorRange.month => '30d',
};

/// "Today 13:58", "Yesterday 22:41", "Sep 23 16:44".
String whenLabel(DateTime t, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final days = DateTime(n.year, n.month, n.day).difference(DateTime(t.year, t.month, t.day)).inDays;
  final hm = DateFormat('HH:mm').format(t);
  if (days == 0) return 'Today $hm';
  if (days == 1) return 'Yesterday $hm';
  return '${DateFormat('MMM d').format(t)} $hm';
}

/// "45 s", "4 min", "2 h 5 min", "3 d".
String durationLabel(Duration d) {
  if (d.inSeconds < 60) return '${d.inSeconds} s';
  if (d.inMinutes < 60) return '${d.inMinutes} min';
  if (d.inHours < 48) {
    final m = d.inMinutes % 60;
    return m == 0 ? '${d.inHours} h' : '${d.inHours} h $m min';
  }
  return '${d.inDays} d';
}

String intervalLabel(int sec) => sec < 60 ? '$sec s' : '${sec ~/ 60} min';

/// Monitor check intervals offered in the options sheet (same as Settings).
const kMonitorIntervals = [30, 60, 300, 900];

/// Incident kinds (down | loss | latency) in plain words.
String incidentKindLabel(String kind) => switch (kind) {
  'down' => 'Outage',
  'loss' => 'Packet loss',
  'latency' => 'Latency spike',
  _ => kind,
};

/// Percent without a trailing ".0": "100%", "99.4%".
String pctLabel(double? v) {
  if (v == null) return '—';
  if (v >= 100 || v % 1 == 0) return '${v.round()}%';
  return '${v.toStringAsFixed(1)}%';
}

String msLabel(double? v) {
  if (v == null) return '—';
  if (v < 10) return v.toStringAsFixed(1);
  return v.round().toString();
}

// ---------------------------------------------------------------------------
// Uptime strip
// ---------------------------------------------------------------------------

/// Reduces the provider's blocks to [count] slots, keeping each slot's worst
/// state (empty < healthy < degraded < down).
List<BlockState> downsampleBlocks(List<BlockState> blocks, int count) {
  if (blocks.length <= count) return blocks;
  return [
    for (var i = 0; i < count; i++)
      () {
        final from = (i * blocks.length / count).floor();
        final to = math.max(from + 1, ((i + 1) * blocks.length / count).floor());
        var worst = BlockState.empty;
        for (var j = from; j < to; j++) {
          if (blocks[j].index > worst.index) worst = blocks[j];
        }
        return worst;
      }(),
  ];
}

Color blockColor(BuildContext context, BlockState b) => switch (b) {
  BlockState.healthy => context.pulse.latFast,
  BlockState.degraded => context.pulse.latMedium,
  BlockState.down => context.pulse.latSlow,
  BlockState.empty => context.colors.surfaceContainerHighest,
};

/// One rounded block per time slot, newest on the right. The latest block is
/// solid, earlier ones at 45%. Failed slots are latSlow, slow ones latMedium.
class UptimeStrip extends StatelessWidget {
  const UptimeStrip({super.key, required this.blocks, this.count = 24, this.height = 22, this.maxGap = 2});

  final List<BlockState> blocks;
  final int count;
  final double height;
  final double maxGap;

  @override
  Widget build(BuildContext context) {
    final slots = downsampleBlocks(blocks, count);
    final failed = slots.where((b) => b == BlockState.down).length;
    final slow = slots.where((b) => b == BlockState.degraded).length;
    final empty = slots.where((b) => b == BlockState.empty).length;
    final summary = [
      'Uptime history, ${slots.length} slots',
      if (failed > 0) '$failed with failed checks',
      if (slow > 0) '$slow slow',
      if (empty > 0) '$empty without data',
      if (failed == 0 && slow == 0 && empty < slots.length) 'all healthy',
    ].join(', ');
    return Semantics(
      label: summary,
      excludeSemantics: true,
      child: SizedBox(
        height: height,
        child: LayoutBuilder(
          builder: (context, box) {
            final n = slots.length;
            final gap = box.maxWidth.isFinite ? math.min(maxGap, box.maxWidth / n * .3) : maxGap;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < n; i++) ...[
                  if (i > 0) SizedBox(width: gap),
                  Expanded(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: slots[i] == BlockState.empty || i == n - 1
                            ? blockColor(context, slots[i])
                            : blockColor(context, slots[i]).withValues(alpha: .45),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Small legend under the targets: what the block colours mean.
class UptimeLegend extends StatelessWidget {
  const UptimeLegend({super.key, this.trailing});
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final style = context.type.labelMedium!.copyWith(
      color: context.colors.onSurfaceVariant,
      fontWeight: FontWeight.w500,
    );
    Widget item(BlockState b, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: blockColor(context, b), borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 6),
        Text(label, style: style),
      ],
    );
    return Wrap(
      spacing: 14,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        item(BlockState.healthy, 'Healthy'),
        item(BlockState.degraded, 'Slow or lossy'),
        item(BlockState.down, 'Failed check'),
        item(BlockState.empty, 'No data'),
        if (trailing != null) Text(trailing!, style: style),
      ],
    );
  }
}

/// Timeout marker: a dashed outline ring (never colour alone; the row also
/// says "No reply").
class DashedRing extends StatelessWidget {
  const DashedRing({super.key, this.size = 14});
  final double size;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _DashedRingPainter(context.pulse.latTimeout));
}

class _DashedRingPainter extends CustomPainter {
  _DashedRingPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    final r = Rect.fromLTWH(1, 1, size.width - 2, size.height - 2);
    const dashes = 8;
    const sweep = 2 * math.pi / dashes;
    for (var i = 0; i < dashes; i++) {
      canvas.drawArc(r, i * sweep, sweep * .55, false, p);
    }
  }

  @override
  bool shouldRepaint(_DashedRingPainter old) => old.color != color;
}

// ---------------------------------------------------------------------------
// Segmented rows
// ---------------------------------------------------------------------------

/// A segmented-list container for rows that need their own layout (the
/// target rows): 24 outer / 6 inner corners, InkWell ripple.
class SegmentedTile extends StatelessWidget {
  const SegmentedTile({
    super.key,
    required this.index,
    required this.count,
    required this.child,
    this.onTap,
    this.color,
    this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 8),
    this.minHeight = 60,
    this.semanticLabel,
  });

  final int index, count;
  final Widget child;
  final VoidCallback? onTap;
  final Color? color;
  final EdgeInsetsGeometry padding;
  final double minHeight;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final body = ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight),
      child: Padding(padding: padding, child: child),
    );
    return Semantics(
      button: onTap != null,
      label: semanticLabel,
      child: Container(
        decoration: BoxDecoration(
          color: color ?? context.colors.surfaceContainer,
          borderRadius: segmentedRadius(index, count),
        ),
        clipBehavior: Clip.antiAlias,
        child: onTap == null
            ? body
            : Material(
                type: MaterialType.transparency,
                child: InkWell(onTap: onTap, child: body),
              ),
      ),
    );
  }
}

/// Leading badge for an incident kind.
class IncidentBadge extends StatelessWidget {
  const IncidentBadge({super.key, required this.kind, this.size = 40});
  final String kind;
  final double size;

  @override
  Widget build(BuildContext context) => switch (kind) {
    'down' => PulseShapeBadge(shape: PulseShape.burst, tone: PulseTone.pink, icon: PulseIcons.power, size: size),
    'loss' => PulseShapeBadge(shape: PulseShape.clover4, tone: PulseTone.lavender, icon: PulseIcons.loss, size: size),
    _ => PulseShapeBadge(shape: PulseShape.sunny, tone: PulseTone.lavender, icon: PulseIcons.timer, size: size),
  };
}

/// One incident: kind, host, start time and duration (or "Ongoing").
class IncidentTile extends StatelessWidget {
  const IncidentTile({super.key, required this.view, required this.host, this.color, this.dense = false});
  final IncidentView view;
  final String host;
  final Color? color;

  /// Narrow cards: no trailing column; duration goes in the subtitle.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final i = view.incident;
    final kind = incidentKindLabel(i.kind);
    final dur = view.ongoing ? 'ongoing' : durationLabel(i.endedAt!.difference(i.startedAt));
    if (dense) {
      return PulseListItem(
        color: color,
        minHeight: 64,
        padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
        leading: IncidentBadge(kind: i.kind, size: 36),
        overline: whenLabel(i.startedAt),
        title: kind,
        subtitle: '$host · $dur\n${i.description}',
        subtitleMaxLines: 3,
      );
    }
    return PulseListItem(
      color: color,
      minHeight: 64,
      leading: IncidentBadge(kind: i.kind),
      title: '$kind · $host',
      subtitle: '${whenLabel(i.startedAt)} · ${i.description}',
      subtitleMaxLines: 2,
      trailing: view.ongoing
          ? const PulsePill('Ongoing', tone: PulsePillTone.pink, dot: true)
          : Text(
              durationLabel(i.endedAt!.difference(i.startedAt)),
              style: context.type.labelLarge!.copyWith(color: context.colors.onSurfaceVariant),
            ),
    );
  }
}
