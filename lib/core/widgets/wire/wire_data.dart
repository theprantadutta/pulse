import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../theme/wire_theme.dart';
import 'wire_pressable.dart';

/// Label + big condensed value.
class WireStat extends StatelessWidget {
  const WireStat({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    this.valueSize = 34,
    this.tone = WireTone.plain,
    this.padding = const EdgeInsets.fromLTRB(16, 14, 16, 14),
    this.valueColor,
    this.caption,
  });

  final String label;
  final String value;
  final String? unit;
  final double valueSize;
  final WireTone tone;
  final EdgeInsetsGeometry padding;

  /// Overrides the value colour (e.g. signal for a live value).
  final Color? valueColor;

  /// Optional mono line under the value.
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final w = context.wire;
    final c = wireRestColors(w, tone);
    return Container(
      color: c.bg,
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: WireType.label().copyWith(color: c.fg),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: value),
                  if (unit != null) TextSpan(text: ' $unit', style: WireType.stat(valueSize * 0.5)),
                ],
              ),
              maxLines: 1,
              style: WireType.stat(valueSize).copyWith(color: valueColor ?? c.fg),
            ),
          ),
          if (caption != null) ...[
            const SizedBox(height: 4),
            Text(caption!, style: WireType.body(11).copyWith(color: tone == WireTone.plain ? w.text2 : c.fg)),
          ],
        ],
      ),
    );
  }
}

/// Hero numeral with its unit suffix at ~28% size in signal.
class WireHeroNumber extends StatelessWidget {
  const WireHeroNumber({
    super.key,
    required this.value,
    this.unit,
    this.size = 190,
    this.color,
    this.unitColor,
    this.fit = true,
  });

  final String value;
  final String? unit;
  final double size;
  final Color? color;
  final Color? unitColor;

  /// Scales down to the available width instead of overflowing.
  final bool fit;

  @override
  Widget build(BuildContext context) {
    final w = context.wire;
    final text = Text.rich(
      TextSpan(
        children: [
          TextSpan(text: value),
          if (unit != null)
            TextSpan(
              text: unit!.toUpperCase(),
              style: WireType.hero(size * 0.286).copyWith(color: unitColor ?? w.signal),
            ),
        ],
      ),
      maxLines: 1,
      softWrap: false,
      style: WireType.hero(size).copyWith(color: color ?? w.ink),
    );
    if (!fit) return text;
    return FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.bottomLeft, child: text);
  }
}

/// A single bar. `null` value = no reply (drawn as a hollow full-height bar).
@immutable
class WireBar {
  const WireBar(this.value, {this.color});
  final double? value;
  final Color? color;
}

/// Bar chart on paper: ink bars, bars above [threshold] in signal,
/// gridlines every [gridStep] px. The newest bar grows in over 120ms linear.
class WireBarChart extends StatefulWidget {
  const WireBarChart({
    super.key,
    required this.bars,
    this.threshold,
    this.slots,
    this.gap = 3,
    this.gridStep = 40,
    this.maxValue,
    this.padding = const EdgeInsets.fromLTRB(16, 16, 16, 0),
  });

  /// Convenience for latency series: timeouts are null.
  factory WireBarChart.latency({
    Key? key,
    required List<double?> values,
    required double threshold,
    int? slots,
    double gridStep = 40,
    EdgeInsetsGeometry padding = const EdgeInsets.fromLTRB(16, 16, 16, 0),
  }) => WireBarChart(
    key: key,
    bars: [for (final v in values) WireBar(v)],
    threshold: threshold,
    slots: slots,
    gridStep: gridStep,
    padding: padding,
  );

  final List<WireBar> bars;
  final double? threshold;

  /// Fixed number of bar slots (bars fill from the right). Defaults to
  /// the number of bars.
  final int? slots;
  final double gap;
  final double gridStep;
  final double? maxValue;
  final EdgeInsetsGeometry padding;

  @override
  State<WireBarChart> createState() => _WireBarChartState();
}

class _WireBarChartState extends State<WireBarChart> with SingleTickerProviderStateMixin {
  late final AnimationController _grow = AnimationController(vsync: this, duration: WireMotion.bars, value: 1);

  @override
  void didUpdateWidget(WireBarChart old) {
    super.didUpdateWidget(old);
    final changed =
        old.bars.length != widget.bars.length ||
        (widget.bars.isNotEmpty && old.bars.isNotEmpty && old.bars.last.value != widget.bars.last.value);
    if (changed) _grow.forward(from: 0);
  }

  @override
  void dispose() {
    _grow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = context.wire;
    return Stack(
      fit: StackFit.expand,
      children: [
        CustomPaint(painter: _GridPainter(w.gridLine, widget.gridStep)),
        Padding(
          padding: widget.padding,
          child: AnimatedBuilder(
            animation: _grow,
            builder: (context, _) => CustomPaint(
              size: Size.infinite,
              painter: _BarChartPainter(
                bars: widget.bars,
                slots: widget.slots ?? widget.bars.length,
                threshold: widget.threshold,
                maxValue: widget.maxValue,
                gap: widget.gap,
                grow: _grow.value,
                ink: w.chartBar,
                signal: w.signal,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Horizontal 1px gridlines every [step] px, measured from the bottom.
class _GridPainter extends CustomPainter {
  _GridPainter(this.color, this.step);
  final Color color;
  final double step;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color;
    for (var y = size.height - step; y > 0; y -= step) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1), p);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => old.color != color || old.step != step;
}

class _BarChartPainter extends CustomPainter {
  _BarChartPainter({
    required this.bars,
    required this.slots,
    required this.threshold,
    required this.maxValue,
    required this.gap,
    required this.grow,
    required this.ink,
    required this.signal,
  });

  final List<WireBar> bars;
  final int slots;
  final double? threshold;
  final double? maxValue;
  final double gap;
  final double grow;
  final Color ink, signal;

  @override
  void paint(Canvas canvas, Size size) {
    if (bars.isEmpty || slots == 0) return;

    final values = bars.map((b) => b.value).whereType<double>();
    final peak = values.isEmpty ? 0.0 : values.reduce(math.max);
    final top = maxValue ?? math.max(peak * 1.12, (threshold ?? 0) * 1.6).clamp(1.0, double.infinity);

    final n = math.max(slots, bars.length);
    final barW = (size.width - gap * (n - 1)) / n;
    final start = n - bars.length;
    for (var i = 0; i < bars.length; i++) {
      final b = bars[i];
      final x = (start + i) * (barW + gap);
      final isLast = i == bars.length - 1;
      final t = isLast ? grow : 1.0;
      if (b.value == null) {
        final p = Paint()
          ..color = signal
          ..style = PaintingStyle.stroke
          ..strokeWidth = kWireBorder;
        final h = size.height * t;
        canvas.drawRect(Rect.fromLTWH(x + 1, size.height - h + 1, barW - 2, h - 1), p);
        continue;
      }
      final h = (b.value! / top).clamp(0.0, 1.0) * size.height * t;
      final color = b.color ?? (threshold != null && b.value! > threshold! ? signal : ink);
      canvas.drawRect(Rect.fromLTWH(x, size.height - math.max(h, 2), barW, math.max(h, 2)), Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_BarChartPainter old) => true;
}

/// A row of N equal status cells separated by 2px gaps.
class WireStatusStrip extends StatelessWidget {
  const WireStatusStrip({super.key, required this.colors, this.height = 26, this.gap = 2, this.borderColor});

  final List<Color> colors;
  final double height;
  final double gap;

  /// Draws a 1px border on every cell (used by block sliders).
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: CustomPaint(painter: _StripPainter(colors, gap, borderColor), size: Size.infinite),
    );
  }
}

class _StripPainter extends CustomPainter {
  _StripPainter(this.colors, this.gap, this.border);
  final List<Color> colors;
  final double gap;
  final Color? border;

  @override
  void paint(Canvas canvas, Size size) {
    if (colors.isEmpty) return;
    final n = colors.length;
    final cw = (size.width - gap * (n - 1)) / n;
    for (var i = 0; i < n; i++) {
      final r = Rect.fromLTWH(i * (cw + gap), 0, cw, size.height);
      canvas.drawRect(r, Paint()..color = colors[i]);
      if (border != null) {
        canvas.drawRect(
          r.deflate(0.5),
          Paint()
            ..color = border!
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_StripPainter old) => old.colors != colors || old.gap != gap || old.border != border;
}

/// 2px-bordered progress bar; the fill has a 2px ink edge.
/// When [value] is null it runs the 1px ink "scanline".
class WireProgress extends StatefulWidget {
  const WireProgress({super.key, required this.value, this.height = 14, this.signal = true});

  final double? value;
  final double height;

  /// Fill in signal (live) or ink (finished).
  final bool signal;

  @override
  State<WireProgress> createState() => _WireProgressState();
}

class _WireProgressState extends State<WireProgress> with SingleTickerProviderStateMixin {
  late final AnimationController _scan = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));

  @override
  void initState() {
    super.initState();
    if (widget.value == null) _scan.repeat();
  }

  @override
  void didUpdateWidget(WireProgress old) {
    super.didUpdateWidget(old);
    if (widget.value == null && !_scan.isAnimating) _scan.repeat();
    if (widget.value != null && _scan.isAnimating) _scan.stop();
  }

  @override
  void dispose() {
    _scan.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = context.wire;
    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        border: Border.all(color: w.ink, width: kWireBorder),
      ),
      child: LayoutBuilder(
        builder: (context, box) {
          if (widget.value == null) {
            return AnimatedBuilder(
              animation: _scan,
              builder: (context, _) => Stack(
                children: [
                  Positioned(
                    left: _scan.value * box.maxWidth,
                    top: 0,
                    bottom: 0,
                    child: Container(width: 1, color: w.ink),
                  ),
                ],
              ),
            );
          }
          final v = widget.value!.clamp(0.0, 1.0);
          return Align(
            alignment: Alignment.centerLeft,
            child: Container(
              width: box.maxWidth * v,
              decoration: BoxDecoration(
                color: widget.signal ? w.signal : w.ink,
                border: v > 0 && v < 1
                    ? Border(
                        right: BorderSide(color: w.ink, width: kWireBorder),
                      )
                    : null,
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Mini bar sparkline (History TREND column).
class WireSparkline extends StatelessWidget {
  const WireSparkline({super.key, required this.values, this.threshold, this.height = 22, this.color});

  final List<double> values;
  final double? threshold;
  final double height;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: WireBarChart(
        bars: [for (final v in values) WireBar(v, color: threshold != null && v > threshold! ? null : color)],
        threshold: threshold,
        gap: 2,
        gridStep: 1000,
        padding: EdgeInsets.zero,
      ),
    );
  }
}

/// N-block strength meter. Hollow blocks mark missing strength.
class WireBlockMeter extends StatelessWidget {
  const WireBlockMeter({
    super.key,
    required this.filled,
    this.total = 4,
    this.blockWidth = 14,
    this.maxHeight = 34,
    this.color,
  });

  final int filled;
  final int total;
  final double blockWidth;
  final double maxHeight;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final w = context.wire;
    final c = color ?? w.ink;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < total; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          Container(
            width: blockWidth,
            height: maxHeight * (i + 1) / total,
            decoration: BoxDecoration(
              color: i < filled ? c : Colors.transparent,
              border: Border.all(color: c, width: kWireBorder),
            ),
          ),
        ],
      ],
    );
  }
}
