import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/widgets/pulse/pulse.dart';
import '../../../providers/loss_provider.dart';

/// Most cells the timeline draws; longer runs fold several packets per cell.
const kMaxTimelineCells = 600;

/// Packets per timeline cell.
int packetsPerCell(int packets) => math.max(1, (packets / kMaxTimelineCells).ceil());

/// Verdict word → pill label and tone.
(String, PulsePillTone) verdictPill(String word) => switch (word) {
  'stable' => ('Stable', PulsePillTone.lime),
  'mostly stable' => ('Mostly stable', PulsePillTone.lime),
  'unstable' => ('Unstable', PulsePillTone.lavender),
  'degraded' => ('Degraded', PulsePillTone.pink),
  _ => ('Measuring', PulsePillTone.outline),
};

/// "1:29".
String fmtClock(Duration d) => '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

/// One cell per packet for the whole run (OK latFast, late latMedium, lost
/// latSlow, future surfaceContainerHighest). Cells pop in as results arrive.
class LossTimeline extends StatefulWidget {
  const LossTimeline({super.key, required this.run, required this.columns, this.gap = 3});

  final LossRun run;
  final int columns;
  final double gap;

  @override
  State<LossTimeline> createState() => _LossTimelineState();
}

class _LossTimelineState extends State<LossTimeline> with SingleTickerProviderStateMixin {
  static const _pop = Duration(milliseconds: 300);
  late final Ticker _ticker = createTicker(_tick);
  late List<PacketState> _cells = _fold(widget.run);
  final _popStart = <int, Duration>{};
  Duration _now = Duration.zero;

  /// Worst state per cell: lost > late > ok > pending.
  static List<PacketState> _fold(LossRun run) {
    final per = packetsPerCell(run.packets.length);
    final n = (run.packets.length / per).ceil();
    return [
      for (var c = 0; c < n; c++)
        run.packets
            .sublist(c * per, math.min(run.packets.length, (c + 1) * per))
            .fold(PacketState.pending, (a, b) => b.index > a.index ? b : a),
    ];
  }

  void _tick(Duration elapsed) {
    setState(() {
      _now = elapsed;
      _popStart.removeWhere((_, start) => elapsed - start > _pop);
    });
    if (_popStart.isEmpty) _ticker.stop();
  }

  @override
  void didUpdateWidget(LossTimeline old) {
    super.didUpdateWidget(old);
    final next = _fold(widget.run);
    if (!PulseMotion.reduced(context) && next.length == _cells.length) {
      var stagger = 0;
      for (var i = 0; i < next.length; i++) {
        if (_cells[i] == PacketState.pending && next[i] != PacketState.pending) {
          // 6 ms stagger between cells that resolve in the same update.
          _popStart[i] = _now + Duration(milliseconds: 6 * stagger++);
        }
      }
      if (_popStart.isNotEmpty && !_ticker.isActive) {
        _now = Duration.zero;
        _popStart.updateAll((_, v) => v - _popStart.values.reduce((a, b) => a < b ? a : b));
        _ticker.start();
      }
    }
    _cells = next;
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.pulse;
    final r = widget.run;
    final scales = <int, double>{
      for (final e in _popStart.entries)
        e.key:
            .3 +
            .7 *
                PulseMotion.spring.transform(
                  ((_now - e.value).inMicroseconds / _pop.inMicroseconds).clamp(0, 1).toDouble(),
                ),
    };
    return Semantics(
      label:
          'Timeline of ${r.packets.length} packets: ${r.sent - r.lost - r.late} OK, ${r.late} late, '
          '${r.lost} lost, ${r.packets.length - r.sent} still to send',
      excludeSemantics: true,
      child: LayoutBuilder(
        builder: (context, box) {
          final cols = widget.columns;
          final size = (box.maxWidth - widget.gap * (cols - 1)) / cols;
          final rows = (_cells.length / cols).ceil();
          return CustomPaint(
            size: Size(box.maxWidth, rows == 0 ? 0 : rows * size + (rows - 1) * widget.gap),
            painter: _TimelinePainter(
              cells: _cells,
              columns: cols,
              cell: size,
              gap: widget.gap,
              scales: scales,
              ok: t.latFast,
              late: t.latMedium,
              lost: t.latSlow,
              pending: context.colors.surfaceContainerHighest,
            ),
          );
        },
      ),
    );
  }
}

class _TimelinePainter extends CustomPainter {
  _TimelinePainter({
    required this.cells,
    required this.columns,
    required this.cell,
    required this.gap,
    required this.scales,
    required this.ok,
    required this.late,
    required this.lost,
    required this.pending,
  });

  final List<PacketState> cells;
  final int columns;
  final double cell, gap;
  final Map<int, double> scales;
  final Color ok, late, lost, pending;

  @override
  void paint(Canvas canvas, Size size) {
    final paints = {
      PacketState.pending: Paint()..color = pending,
      PacketState.ok: Paint()..color = ok,
      PacketState.late: Paint()..color = late,
      PacketState.lost: Paint()..color = lost,
    };
    final radius = Radius.circular(cell * .33);
    for (var i = 0; i < cells.length; i++) {
      final x = (i % columns) * (cell + gap);
      final y = (i ~/ columns) * (cell + gap);
      var rect = Rect.fromLTWH(x, y, cell, cell);
      final s = scales[i];
      if (s != null) rect = Rect.fromCenter(center: rect.center, width: cell * s, height: cell * s);
      canvas.drawRRect(RRect.fromRectAndRadius(rect, radius), paints[cells[i]]!);
    }
  }

  @override
  bool shouldRepaint(_TimelinePainter old) => true;
}

/// Small legend swatch + label.
class LegendDot extends StatelessWidget {
  const LegendDot({super.key, required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
      ),
      const SizedBox(width: 5),
      Text(label, style: context.type.labelMedium!.copyWith(color: context.colors.onSurfaceVariant)),
    ],
  );
}
