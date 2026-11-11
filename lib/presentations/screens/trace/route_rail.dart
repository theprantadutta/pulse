import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../../core/format.dart';
import '../../../core/widgets/pulse/pulse.dart';
import 'trace_insights.dart';

/// Route rail (DESIGN_SYSTEM.md §8): a sine path through every hop, 5 px dots
/// coloured by latency, timeouts as dashed rings, the destination as a spinning
/// cookie9, a "+55" callout above the biggest jump, and labels under the path.
///
/// The path draws on with PathMetric (1.6 s) and new nodes pop (0 → 1.3 → 1)
/// as hops resolve. Static when animations are disabled.
///
/// Reusable: History builds [insights] from a saved session with
/// `TraceInsights.of(hops.map(traceHopFromJson).toList(), ...)`.
class TraceRouteRail extends StatefulWidget {
  const TraceRouteRail({super.key, required this.insights, this.background, this.height = 72});

  final TraceInsights insights;

  /// Colour behind the rail (the card), used to ring the destination cookie.
  final Color? background;
  final double height;

  @override
  State<TraceRouteRail> createState() => _TraceRouteRailState();
}

class _TraceRouteRailState extends State<TraceRouteRail> with TickerProviderStateMixin {
  late final AnimationController _draw = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));
  late final AnimationController _pop = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));
  late final AnimationController _spin = AnimationController(vsync: this, duration: PulseMotion.smallSpin);

  /// Nodes below this index are fully shown; the rest pop with [_pop].
  int _popFrom = 0;
  double _drawFrom = 0;
  bool _reduce = false;

  int get _count => widget.insights.hops.length;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = PulseMotion.reduced(context);
    if (reduce != _reduce || !_draw.isAnimating && _draw.value == 0) {
      _reduce = reduce;
      if (reduce) {
        _draw.value = 1;
        _pop.value = 1;
        _popFrom = _count;
      } else if (_count > 0 && _draw.value == 0) {
        _start(0);
      }
    }
    _syncSpin();
  }

  @override
  void didUpdateWidget(TraceRouteRail old) {
    super.didUpdateWidget(old);
    final before = old.insights.hops.length;
    if (_count != before) {
      if (_reduce) {
        _popFrom = _count;
      } else {
        _start(_count > before ? before : 0);
      }
    }
    _syncSpin();
  }

  void _start(int from) {
    _popFrom = from;
    _drawFrom = _count <= 1 ? 0 : (from - 1).clamp(0, _count - 1) / (_count - 1);
    final stagger = 40 * (_count - from).clamp(0, 12);
    _pop.duration = Duration(milliseconds: 450 + stagger);
    _pop.forward(from: 0);
    _draw.forward(from: 0);
  }

  void _syncSpin() {
    if (widget.insights.reached && !_reduce) {
      if (!_spin.isAnimating) _spin.repeat();
    } else {
      _spin.stop();
    }
  }

  @override
  void dispose() {
    _draw.dispose();
    _pop.dispose();
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ins = widget.insights;
    final labelStyle = pulseText(11, 600).copyWith(color: c.onSurfaceVariant);
    final scaler = MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.3);
    return Semantics(
      label: ins.semanticSummary,
      image: true,
      excludeSemantics: true,
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: AnimatedBuilder(
          animation: Listenable.merge([_draw, _pop, _spin]),
          builder: (context, _) => CustomPaint(
            painter: _RailPainter(
              insights: ins,
              tokens: context.pulse,
              colors: c,
              background: widget.background ?? c.surfaceContainer,
              labelStyle: labelStyle,
              textScaler: scaler,
              draw: _drawFrom + (1 - _drawFrom) * PulseMotion.emphasizedDecelerate.transform(_draw.value),
              pop: _pop.value,
              popFrom: _popFrom,
              popDuration: _pop.duration!.inMilliseconds.toDouble(),
              spin: _spin.value,
            ),
          ),
        ),
      ),
    );
  }
}

class _RailPainter extends CustomPainter {
  _RailPainter({
    required this.insights,
    required this.tokens,
    required this.colors,
    required this.background,
    required this.labelStyle,
    required this.textScaler,
    required this.draw,
    required this.pop,
    required this.popFrom,
    required this.popDuration,
    required this.spin,
  });

  final TraceInsights insights;
  final PulseTokens tokens;
  final ColorScheme colors;
  final Color background;
  final TextStyle labelStyle;
  final TextScaler textScaler;
  final double draw, pop, spin, popDuration;
  final int popFrom;

  static const _mid = 30.0;
  static const _amp = 9.0;
  static const _freq = .62;

  double _y(double i) => _mid + _amp * math.sin(i * _freq);

  /// 0 → 1.3 → 1 node pop for node [i], staggered 40 ms.
  double _popScale(int i) {
    if (i < popFrom) return 1;
    final total = popDuration;
    final t = ((pop * total - 40 * (i - popFrom).clamp(0, 12)) / 450).clamp(0.0, 1.0);
    if (t < .6) return 1.3 * Curves.easeOut.transform(t / .6);
    return 1.3 - .3 * Curves.easeInOut.transform((t - .6) / .4);
  }

  TextPainter _text(String s, TextStyle style) => TextPainter(
    text: TextSpan(text: s, style: style),
    textDirection: TextDirection.ltr,
    textScaler: textScaler,
  )..layout();

  @override
  void paint(Canvas canvas, Size size) {
    final hops = insights.hops;
    final n = hops.length;
    const padL = 8.0;
    final reached = insights.reached;
    final padR = reached ? 13.0 : 8.0;
    final width = size.width - padL - padR;
    if (n == 0 || width <= 0) {
      // Empty track while resolving the target.
      final track = Paint()
        ..color = colors.secondaryContainer
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      final p = Path()..moveTo(padL, _y(0));
      for (var x = 0.0; x <= width; x += 3) {
        p.lineTo(padL + x, _y(x / 16));
      }
      canvas.drawPath(p, track..color = colors.secondaryContainer.withValues(alpha: .5));
      return;
    }
    final step = n == 1 ? 0.0 : width / (n - 1);
    double xOf(int i) => padL + i * step;

    // Sine path through all nodes, drawn on with PathMetric.
    final path = Path()..moveTo(padL, _y(0));
    if (n > 1) {
      for (var t = 0.0; t <= n - 1 + 1e-6; t += .2) {
        path.lineTo(padL + t * step, _y(t));
      }
    }
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = colors.secondaryContainer;
    for (final m in path.computeMetrics()) {
      canvas.drawPath(m.extractPath(0, m.length * draw.clamp(0.0, 1.0)), stroke);
    }

    final r = math.max(2.0, math.min(5.0, step * .42));
    for (var i = 0; i < n; i++) {
      final s = _popScale(i);
      if (s <= 0) continue;
      final h = hops[i];
      final center = Offset(xOf(i), _y(i.toDouble()));
      final isDest = reached && i == n - 1;
      if (isDest) {
        final shape = pulseShapePath(
          PulseShape.cookie9,
          Rect.fromCircle(center: center, radius: 11.5 * s),
          rotation: spin * 2 * math.pi,
        );
        canvas.drawPath(shape, Paint()..color = colors.primaryFixedDim);
        canvas.drawPath(
          shape,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = background,
        );
      } else if (h.timedOut) {
        final rr = (r - .5) * s;
        canvas.drawCircle(center, rr, Paint()..color = background);
        _dashedCircle(canvas, center, rr, tokens.latTimeout);
      } else if (h.avg == null) {
        // Still probing: hollow ring in the track colour.
        canvas.drawCircle(
          center,
          (r - .5) * s,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = colors.outlineVariant,
        );
      } else {
        canvas.drawCircle(center, r * s, Paint()..color = tokens.latencyColor(h.avg));
      }
    }

    // "+55" callout above the biggest jump.
    final j = insights.jump;
    if (j != null) {
      final i = hops.indexWhere((h) => h.n == j.to);
      if (i >= 0 && _popScale(i) > 0) {
        final tp = _text(
          '+${fmtMs(j.addMs)}',
          pulseText(10, 800, wdth: 105).copyWith(color: colors.onPrimaryContainer),
        );
        final w = math.max(36.0, tp.width + 14);
        final h = math.max(16.0, tp.height + 2);
        final cx = xOf(i).clamp(w / 2, size.width - w / 2);
        final rect = RRect.fromRectAndRadius(Rect.fromLTWH(cx - w / 2, 0, w, h), Radius.circular(h / 2));
        canvas.drawRRect(rect, Paint()..color = colors.primaryContainer);
        tp.paint(canvas, Offset(cx - tp.width / 2, (h - tp.height) / 2));
      }
    }

    // Labels: You · origin · destination.
    final labelTop = _mid + _amp + 14;
    final you = _text('You', labelStyle);
    you.paint(canvas, Offset(2, labelTop));
    var leftEdge = 2 + you.width + 8;
    final destName = insights.destinationLabel;
    var rightEdge = size.width;
    if (destName != null) {
      final d = _text(destName, labelStyle);
      final x = math.max(leftEdge, size.width - 2 - d.width);
      if (x + d.width <= size.width) {
        d.paint(canvas, Offset(x, labelTop));
        rightEdge = x - 8;
      }
    }
    final origin = insights.originLabel;
    if (origin != null && origin.label != destName) {
      final o = _text(origin.label, labelStyle);
      final x = (xOf(origin.index) - o.width / 2).clamp(leftEdge, math.max(leftEdge, rightEdge - o.width)).toDouble();
      if (x + o.width <= rightEdge) o.paint(canvas, Offset(x, labelTop));
      leftEdge = x + o.width;
    }
  }

  void _dashedCircle(Canvas canvas, Offset c, double r, Color color) {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = color;
    const dashes = 8;
    for (var k = 0; k < dashes; k++) {
      final a = k * 2 * math.pi / dashes;
      canvas.drawArc(Rect.fromCircle(center: c, radius: r), a, math.pi / dashes, false, p);
    }
  }

  @override
  bool shouldRepaint(_RailPainter old) =>
      old.insights != insights ||
      old.draw != draw ||
      old.pop != pop ||
      old.spin != spin ||
      old.popFrom != popFrom ||
      old.background != background ||
      old.colors != colors ||
      old.labelStyle != labelStyle;
}

/// A dashed circle outline: the "no reply" marker (timeouts are never colour
/// alone). [child] sits centred inside it.
class DashedRing extends StatelessWidget {
  const DashedRing({super.key, required this.size, this.color, this.child, this.strokeWidth = 2});

  final double size;
  final Color? color;
  final Widget? child;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(size),
    painter: _DashedRingPainter(color ?? context.colors.outline, strokeWidth),
    child: SizedBox.square(
      dimension: size,
      child: child == null ? null : Center(child: child),
    ),
  );
}

class _DashedRingPainter extends CustomPainter {
  _DashedRingPainter(this.color, this.strokeWidth);
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.shortestSide / 2 - strokeWidth / 2;
    final dashes = math.max(6, (2 * math.pi * r / 7).round());
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = color;
    for (var k = 0; k < dashes; k++) {
      final a = k * 2 * math.pi / dashes;
      canvas.drawArc(Rect.fromCircle(center: size.center(Offset.zero), radius: r), a, math.pi / dashes, false, p);
    }
  }

  @override
  bool shouldRepaint(_DashedRingPainter old) => old.color != color || old.strokeWidth != strokeWidth;
}
