import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/widgets/pulse/pulse.dart';
import '../../../services/net/port_scanner.dart';

/// State of one port-map cell (a cell can stand for several ports).
enum PortCell { pending, closed, filtered, open }

/// Ports per cell so a scan never draws more than 256 cells.
int portsPerCell(int ports) => math.max(1, (ports / 256).ceil());

/// Folds per-port results into cells: open wins over filtered over closed; a
/// cell with any unscanned port is pending.
List<PortCell> portCells(List<int> ports, Map<int, PortResult> results) {
  final per = portsPerCell(ports.length);
  final count = (ports.length / per).ceil();
  return [
    for (var c = 0; c < count; c++)
      () {
        var open = false, filtered = false, pending = false;
        for (var i = c * per; i < math.min(ports.length, (c + 1) * per); i++) {
          final r = results[ports[i]];
          if (r == null) {
            pending = true;
          } else if (r.state == PortState.open) {
            open = true;
          } else if (r.state == PortState.filtered) {
            filtered = true;
          }
        }
        if (open) return PortCell.open;
        if (filtered) return PortCell.filtered;
        if (pending) return PortCell.pending;
        return PortCell.closed;
      }(),
  ];
}

/// Grid of rounded cells: open pink, filtered lavender, closed outline only,
/// not-yet-scanned a faint outline. Cells pop in (300 ms spring from .3) in
/// scan order as results arrive.
class PortMap extends StatefulWidget {
  const PortMap({
    super.key,
    required this.cells,
    required this.columns,
    this.maxCell = 21,
    this.gap = 4,
    this.semanticLabel,
  });

  final List<PortCell> cells;
  final int columns;
  final double maxCell;
  final double gap;
  final String? semanticLabel;

  @override
  State<PortMap> createState() => _PortMapState();
}

class _PortMapState extends State<PortMap> with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_tick);
  Duration _now = Duration.zero;

  /// When each cell started popping (ticker time).
  final _popAt = <int, Duration>{};

  static const _popMs = 300;

  @override
  void didUpdateWidget(PortMap old) {
    super.didUpdateWidget(old);
    if (PulseMotion.reduced(context)) return;
    if (old.cells.length != widget.cells.length) _popAt.clear();
    var batch = 0;
    for (var i = 0; i < widget.cells.length; i++) {
      final before = i < old.cells.length ? old.cells[i] : PortCell.pending;
      if (before == PortCell.pending && widget.cells[i] != PortCell.pending) {
        _popAt[i] = _now + Duration(milliseconds: 6 * math.min(batch++, 40));
      }
    }
    if (_popAt.isNotEmpty && !_ticker.isActive) _ticker.start();
  }

  void _tick(Duration elapsed) {
    setState(() => _now = elapsed);
    _popAt.removeWhere((_, at) => elapsed - at > const Duration(milliseconds: _popMs));
    if (_popAt.isEmpty) {
      _ticker.stop();
      _now = Duration.zero;
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  double _scale(int i) {
    final at = _popAt[i];
    if (at == null) return 1;
    final t = ((_now - at).inMicroseconds / (_popMs * 1000)).clamp(0.0, 1.0);
    return .3 + .7 * PulseMotion.spring.transform(t);
  }

  @override
  Widget build(BuildContext context) {
    final cols = widget.columns;
    final rows = (widget.cells.length / cols).ceil();
    return Semantics(
      label: widget.semanticLabel,
      image: true,
      excludeSemantics: true,
      child: LayoutBuilder(
        builder: (context, box) {
          final gap = widget.gap;
          final cell = math.min(widget.maxCell, (box.maxWidth - gap * (cols - 1)) / cols);
          return CustomPaint(
            size: Size(box.maxWidth, rows * cell + (rows - 1) * gap),
            painter: _PortMapPainter(
              cells: widget.cells,
              columns: cols,
              cell: cell,
              gap: gap,
              scale: _scale,
              open: PulseTone.pink.fill(context),
              filtered: PulseTone.lavender.fill(context),
              outline: context.colors.outlineVariant,
              tick: _now,
            ),
          );
        },
      ),
    );
  }
}

class _PortMapPainter extends CustomPainter {
  _PortMapPainter({
    required this.cells,
    required this.columns,
    required this.cell,
    required this.gap,
    required this.scale,
    required this.open,
    required this.filtered,
    required this.outline,
    required this.tick,
  });

  final List<PortCell> cells;
  final int columns;
  final double cell, gap;
  final double Function(int) scale;
  final Color open, filtered, outline;
  final Duration tick;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = Radius.circular(cell * .3);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (var i = 0; i < cells.length; i++) {
      final x = (i % columns) * (cell + gap), y = (i ~/ columns) * (cell + gap);
      final s = scale(i);
      final rect = Rect.fromCenter(center: Offset(x + cell / 2, y + cell / 2), width: cell * s, height: cell * s);
      final rr = RRect.fromRectAndRadius(rect, radius);
      switch (cells[i]) {
        case PortCell.open:
          canvas.drawRRect(rr, Paint()..color = open);
        case PortCell.filtered:
          canvas.drawRRect(rr, Paint()..color = filtered);
        case PortCell.closed:
          canvas.drawRRect(rr.deflate(.75), stroke..color = outline);
        case PortCell.pending:
          canvas.drawRRect(rr.deflate(.75), stroke..color = outline.withValues(alpha: .4));
      }
    }
  }

  @override
  bool shouldRepaint(_PortMapPainter old) =>
      old.cells != cells ||
      old.tick != tick ||
      old.cell != cell ||
      old.open != open ||
      old.filtered != filtered ||
      old.outline != outline;
}

/// Small legend square.
class PortLegend extends StatelessWidget {
  const PortLegend(this.label, {super.key, required this.cell});
  final String label;
  final PortCell cell;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fill = switch (cell) {
      PortCell.open => PulseTone.pink.fill(context),
      PortCell.filtered => PulseTone.lavender.fill(context),
      _ => null,
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(3),
            border: fill == null ? Border.all(color: c.outlineVariant, width: 1.5) : null,
          ),
        ),
        const SizedBox(width: 5),
        Text(label, style: context.type.labelMedium!.copyWith(color: c.onSurfaceVariant)),
      ],
    );
  }
}
