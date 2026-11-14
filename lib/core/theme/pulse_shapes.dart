// Pulse — Expressive shapes, wavy progress indicators and the animated logo.
//
// Drop into lib/theme/pulse_shapes.dart. Pure Flutter, no packages.
// Every animated widget here respects MediaQuery.disableAnimations (system
// "remove animations" / reduce-motion) and the app's own motion toggle if you
// wrap it in a MediaQuery override.

import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'pulse_theme.dart' show PulseBrand;

// ---------------------------------------------------------------------------
// Shape family
// ---------------------------------------------------------------------------

enum PulseShape {
  circle,
  square,
  arch,
  diamond,
  pill,
  slanted,
  cookie12,
  cookie9,
  cookie7,
  cookie4,
  clover4,
  clover8,
  sunny,
  burst,
  flower,
}

class _Polar {
  const _Polar(this.scallops, this.depth);
  final int scallops;
  final double depth;
}

const Map<PulseShape, _Polar> _polar = <PulseShape, _Polar>{
  PulseShape.cookie12: _Polar(12, 0.10),
  PulseShape.cookie9: _Polar(9, 0.11),
  PulseShape.cookie7: _Polar(7, 0.12),
  PulseShape.cookie4: _Polar(4, 0.09),
  PulseShape.clover4: _Polar(4, 0.20),
  PulseShape.clover8: _Polar(8, 0.14),
  PulseShape.sunny: _Polar(10, 0.08),
  PulseShape.burst: _Polar(12, 0.16),
  PulseShape.flower: _Polar(8, 0.22),
};

/// Scalloped "cookie" outline: r(θ) = R + A·cos(nθ), starting at 12 o'clock.
/// [depth] is the scallop amplitude as a fraction of the outer radius.
Path polarPath(Rect rect, {required int scallops, required double depth, double rotation = 0, int? samples}) {
  final c = rect.center;
  final outer = rect.shortestSide / 2;
  final a = outer * depth;
  final r0 = outer - a;
  final n = samples ?? scallops * 16;
  final path = Path();
  for (var i = 0; i <= n; i++) {
    final t = 2 * math.pi * i / n;
    final r = r0 + a * math.cos(scallops * t);
    final ang = t - math.pi / 2 + rotation;
    final x = c.dx + r * math.cos(ang);
    final y = c.dy + r * math.sin(ang);
    if (i == 0) {
      path.moveTo(x, y);
    } else {
      path.lineTo(x, y);
    }
  }
  return path..close();
}

/// Outline of any [PulseShape] inside [rect]. [rotation] (radians) applies to
/// the scalloped shapes, which is what the spinning hero uses.
Path pulseShapePath(PulseShape shape, Rect rect, {double rotation = 0}) {
  final p = _polar[shape];
  if (p != null) return polarPath(rect, scallops: p.scallops, depth: p.depth, rotation: rotation);
  final w = rect.width, h = rect.height, l = rect.left, top = rect.top;
  switch (shape) {
    case PulseShape.circle:
      return Path()..addOval(rect);
    case PulseShape.square:
      return Path()..addRRect(RRect.fromRectAndRadius(rect.deflate(w * 0.04), Radius.circular(w * 0.30)));
    case PulseShape.pill:
      return Path()..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(l + w * 0.2, top + h * 0.02, w * 0.6, h * 0.96),
          Radius.circular(w * 0.3),
        ),
      );
    case PulseShape.arch:
      final r = w * 0.46;
      return Path()
        ..moveTo(l + w * 0.04, top + h * 0.5)
        ..arcToPoint(Offset(l + w * 0.96, top + h * 0.5), radius: Radius.circular(r))
        ..lineTo(l + w * 0.96, top + h * 0.80)
        ..arcToPoint(Offset(l + w * 0.80, top + h * 0.96), radius: Radius.circular(w * 0.16))
        ..lineTo(l + w * 0.20, top + h * 0.96)
        ..arcToPoint(Offset(l + w * 0.04, top + h * 0.80), radius: Radius.circular(w * 0.16))
        ..close();
    case PulseShape.diamond:
      final side = w * 0.66;
      final sq = RRect.fromRectAndRadius(
        Rect.fromCenter(center: rect.center, width: side, height: side),
        Radius.circular(w * 0.18),
      );
      final m = Matrix4.identity()
        ..setEntry(0, 3, rect.center.dx)
        ..setEntry(1, 3, rect.center.dy);
      final rot = Matrix4.rotationZ(math.pi / 4);
      final back = Matrix4.identity()
        ..setEntry(0, 3, -rect.center.dx)
        ..setEntry(1, 3, -rect.center.dy);
      final mat = m.multiplied(rot)..multiply(back);
      return (Path()..addRRect(sq)).transform(mat.storage);
    case PulseShape.slanted:
      return Path()
        ..moveTo(l + w * 0.22, top + h * 0.08)
        ..lineTo(l + w * 0.84, top + h * 0.08)
        ..quadraticBezierTo(l + w * 0.99, top + h * 0.08, l + w * 0.956, top + h * 0.23)
        ..lineTo(l + w * 0.806, top + h * 0.85)
        ..quadraticBezierTo(l + w * 0.77, top + h * 0.94, l + w * 0.69, top + h * 0.94)
        ..lineTo(l + w * 0.16, top + h * 0.94)
        ..quadraticBezierTo(l + w * 0.01, top + h * 0.94, l + w * 0.044, top + h * 0.79)
        ..lineTo(l + w * 0.194, top + h * 0.17)
        ..quadraticBezierTo(l + w * 0.23, top + h * 0.08, l + w * 0.22, top + h * 0.08)
        ..close();
    default:
      return Path()..addOval(rect);
  }
}

/// Use with Container(decoration: ShapeDecoration(shape: PulseShapeBorder(...))),
/// Material(shape: ...), ClipPath(clipper: ShapeBorderClipper(shape: ...)), etc.
class PulseShapeBorder extends ShapeBorder {
  const PulseShapeBorder(this.shape, {this.rotation = 0});
  final PulseShape shape;
  final double rotation;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) => getOuterPath(rect, textDirection: textDirection);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) => pulseShapePath(shape, rect, rotation: rotation);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {}

  @override
  ShapeBorder scale(double t) => this;

  @override
  bool operator ==(Object other) => other is PulseShapeBorder && other.shape == shape && other.rotation == rotation;

  @override
  int get hashCode => Object.hash(shape, rotation);
}

bool _reduceMotion(BuildContext context) => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

/// A filled shape with an upright child. Set [spin] to rotate only the shape
/// (hero cookie: 28 s, small badges: 10 s). [breathe] adds the 1.2 s scale pulse.
class PulseShapeBox extends StatefulWidget {
  const PulseShapeBox({
    super.key,
    required this.shape,
    required this.color,
    required this.size,
    this.child,
    this.spin,
    this.breathe = false,
  });

  final PulseShape shape;
  final Color color;
  final double size;
  final Widget? child;
  final Duration? spin;
  final bool breathe;

  @override
  State<PulseShapeBox> createState() => _PulseShapeBoxState();
}

class _PulseShapeBoxState extends State<PulseShapeBox> with TickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: widget.spin ?? const Duration(seconds: 28),
  );
  late final AnimationController _breathe = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(PulseShapeBox old) {
    super.didUpdateWidget(old);
    if (widget.spin != null && widget.spin != _spin.duration) _spin.duration = widget.spin;
    if (old.spin != widget.spin || old.breathe != widget.breathe) _sync();
  }

  /// Starts or rests the loops for the current [PulseShapeBox.spin] /
  /// [PulseShapeBox.breathe] and the reduce-motion setting.
  void _sync() {
    final reduce = _reduceMotion(context);
    if (widget.spin != null && !reduce) {
      if (!_spin.isAnimating) _spin.repeat();
    } else {
      _spin.stop();
    }
    if (widget.breathe && !reduce) {
      if (!_breathe.isAnimating) _breathe.repeat(reverse: true);
    } else {
      _breathe.stop();
      _breathe.value = 0;
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    _breathe.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[_spin, _breathe]),
      builder: (context, child) {
        final scale = 1 + 0.035 * Curves.easeInOut.transform(_breathe.value);
        return Transform.scale(
          scale: scale,
          child: SizedBox.square(
            dimension: widget.size,
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: ShapeDecoration(
                      color: widget.color,
                      shape: PulseShapeBorder(widget.shape, rotation: _spin.value * 2 * math.pi),
                    ),
                  ),
                ),
                ?child,
              ],
            ),
          ),
        );
      },
      child: widget.child,
    );
  }
}

// ---------------------------------------------------------------------------
// Wavy progress indicators (M3 Expressive)
// ---------------------------------------------------------------------------

class WavyLinearProgressPainter extends CustomPainter {
  WavyLinearProgressPainter({
    required this.progress,
    required this.phase,
    required this.activeColor,
    required this.trackColor,
    this.amplitude = 3,
    this.wavelength = 24,
    this.strokeWidth = 4,
    this.gap = 8,
  });

  final double progress; // 0..1
  final double phase; // 0..1, animate with a repeating controller (1.1 s)
  final Color activeColor, trackColor;
  final double amplitude, wavelength, strokeWidth, gap;

  @override
  void paint(Canvas canvas, Size size) {
    final mid = size.height / 2;
    final end = size.width * progress.clamp(0.0, 1.0);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth;
    final wave = Path();
    final start = strokeWidth / 2;
    for (var x = start; x <= end; x += 1) {
      final y = mid + math.sin((x / wavelength - phase) * 2 * math.pi) * amplitude;
      if (x == start) {
        wave.moveTo(x, y);
      } else {
        wave.lineTo(x, y);
      }
    }
    canvas.drawPath(wave, paint..color = activeColor);
    if (progress < 1) {
      final trackStart = end + gap;
      final trackEnd = size.width - strokeWidth * 2;
      if (trackEnd > trackStart) {
        canvas.drawLine(Offset(trackStart, mid), Offset(trackEnd, mid), paint..color = trackColor);
      }
      // stop indicator
      canvas.drawCircle(Offset(size.width - strokeWidth / 2, mid), strokeWidth / 2 + 0.5, Paint()..color = activeColor);
    }
  }

  @override
  bool shouldRepaint(covariant WavyLinearProgressPainter old) =>
      old.progress != progress ||
      old.phase != phase ||
      old.amplitude != amplitude ||
      old.activeColor != activeColor ||
      old.trackColor != trackColor;
}

class WavyCircularProgressPainter extends CustomPainter {
  WavyCircularProgressPainter({
    required this.progress,
    required this.phase,
    required this.activeColor,
    required this.trackColor,
    this.waves = 16,
    this.amplitudeFactor = 4 / 120,
    this.strokeWidth = 11,
    this.trackWidth = 12,
  });

  final double progress, phase;
  final Color activeColor, trackColor;
  final int waves;
  final double amplitudeFactor, strokeWidth, trackWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final radius = size.shortestSide / 2 * 0.8; // matches the 120/150 ratio of the mock
    canvas.drawCircle(
      c,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = trackWidth
        ..color = trackColor,
    );
    final sweep = 2 * math.pi * progress.clamp(0.0, 1.0);
    if (sweep <= 0) return;
    final amp = radius * amplitudeFactor;
    final steps = math.max(8, (sweep * radius / 2).round());
    final path = Path();
    for (var i = 0; i <= steps; i++) {
      final a = -math.pi / 2 + sweep * i / steps;
      final r = radius + amp * math.sin(waves * a + phase * 2 * math.pi);
      final p = Offset(c.dx + r * math.cos(a), c.dy + r * math.sin(a));
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = strokeWidth
        ..color = activeColor,
    );
  }

  @override
  bool shouldRepaint(covariant WavyCircularProgressPainter old) =>
      old.progress != progress ||
      old.phase != phase ||
      old.amplitudeFactor != amplitudeFactor ||
      old.activeColor != activeColor ||
      old.trackColor != trackColor;
}

/// Determinate wavy indicator. [circular] = speed-test gauge; otherwise linear.
/// The value animates with the expressive spring; the wave travels forever.
class WavyProgress extends StatefulWidget {
  const WavyProgress({
    super.key,
    required this.value,
    this.circular = false,
    this.size = const Size(double.infinity, 14),
    this.activeColor,
    this.trackColor,
    this.child,
  });

  final double value;
  final bool circular;
  final Size size;
  final Color? activeColor, trackColor;
  final Widget? child; // centered inside the circular gauge

  @override
  State<WavyProgress> createState() => _WavyProgressState();
}

class _WavyProgressState extends State<WavyProgress> with TickerProviderStateMixin {
  late final AnimationController _phase = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );
  late final AnimationController _value = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
    value: 0,
  );
  // 0 = wavy, 1 = flat. A finished bar (value 1) settles into a straight line
  // and stops moving, so it never reads as "still loading" (M3 Expressive).
  late final AnimationController _flat =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 600), value: widget.value >= 1 ? 1 : 0)
        ..addStatusListener((status) {
          if (status == AnimationStatus.completed) _phase.stop();
        });
  double _from = 0, _to = 0;

  bool get _done => widget.value >= 1;

  @override
  void initState() {
    super.initState();
    _to = widget.value;
    _value.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncPhase();
  }

  void _syncPhase() {
    if (_reduceMotion(context)) {
      _phase.stop();
      _value.value = 1;
      _flat.value = _done ? 1 : 0;
    } else if (_done && _flat.isCompleted) {
      _phase.stop();
    } else if (!_phase.isAnimating) {
      _phase.repeat();
    }
  }

  @override
  void didUpdateWidget(WavyProgress old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      _from = _current;
      _to = widget.value;
      _value.forward(from: 0);
      final wasDone = old.value >= 1;
      if (_done && !wasDone) {
        // Let the fill reach the end, then flatten.
        _flat.animateTo(1, curve: Curves.easeOutCubic);
      } else if (!_done && wasDone) {
        _flat.value = 0;
      }
      _syncPhase();
    }
  }

  double get _current => _from + (_to - _from) * const Cubic(0.05, 0.7, 0.1, 1).transform(_value.value);

  @override
  void dispose() {
    _phase.dispose();
    _value.dispose();
    _flat.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[_phase, _value, _flat]),
      builder: (context, child) {
        final painter = widget.circular
            ? WavyCircularProgressPainter(
                progress: _current,
                phase: _phase.value,
                amplitudeFactor: 4 / 120 * (1 - _flat.value),
                activeColor: widget.activeColor ?? cs.primaryFixedDim,
                trackColor: widget.trackColor ?? cs.surfaceContainerHigh,
              )
            : WavyLinearProgressPainter(
                progress: _current,
                phase: _phase.value,
                amplitude: 3 * (1 - _flat.value),
                activeColor: widget.activeColor ?? cs.primary,
                trackColor: widget.trackColor ?? cs.secondaryContainer,
              );
        return CustomPaint(size: widget.size, painter: painter, child: child);
      },
      child: widget.circular && widget.child != null
          ? SizedBox.fromSize(
              size: widget.size,
              child: Center(child: widget.child),
            )
          : null,
    );
  }
}

// ---------------------------------------------------------------------------
// Logo A — "Heartbeat Cookie"
// ---------------------------------------------------------------------------

/// The Pulse mark. Animated: cookie spins (24 s), heartbeat draws on/off and
/// the mark pumps (2.4 s loop). Static when animations are disabled.
class PulseLogo extends StatefulWidget {
  const PulseLogo({super.key, this.size = 120, this.animated = true, this.tile = false, this.mono});

  final double size;
  final bool animated;
  final bool tile; // draw the berry app-icon squircle behind the mark
  final Color? mono; // single-color variant (e.g. themed icons): cookie in [mono], line cut out

  @override
  State<PulseLogo> createState() => _PulseLogoState();
}

class _PulseLogoState extends State<PulseLogo> with TickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(vsync: this, duration: const Duration(seconds: 24));
  late final AnimationController _beat = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
    value: 0.5,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.animated && !_reduceMotion(context)) {
      if (!_spin.isAnimating) _spin.repeat();
      if (!_beat.isAnimating) _beat.repeat();
    } else {
      _spin.stop();
      _beat.stop();
      _beat.value = 0.5; // fully drawn heartbeat, scale 1
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    _beat.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Pulse',
      image: true,
      child: AnimatedBuilder(
        animation: Listenable.merge(<Listenable>[_spin, _beat]),
        builder: (context, _) => CustomPaint(
          size: Size.square(widget.size),
          painter: PulseLogoPainter(spin: _spin.value, beat: _beat.value, tile: widget.tile, mono: widget.mono),
        ),
      ),
    );
  }
}

class PulseLogoPainter extends CustomPainter {
  PulseLogoPainter({this.spin = 0, this.beat = 0.5, this.tile = false, this.mono});

  final double spin, beat;
  final bool tile;
  final Color? mono;

  static Path heartbeatPath() => Path()
    ..moveTo(26, 62)
    ..lineTo(43, 62)
    ..lineTo(50, 46)
    ..lineTo(60, 80)
    ..lineTo(69, 38)
    ..lineTo(76, 62)
    ..lineTo(94, 62);

  double _pump(double t) {
    // keyframes: 0→1, .30→1.06, .45→.98, .60→1.02, 1→1
    const k = <List<double>>[
      [0, 1],
      [0.30, 1.06],
      [0.45, 0.98],
      [0.60, 1.02],
      [1, 1],
    ];
    for (var i = 0; i < k.length - 1; i++) {
      if (t <= k[i + 1][0]) {
        final f = (t - k[i][0]) / (k[i + 1][0] - k[i][0]);
        return k[i][1] + (k[i + 1][1] - k[i][1]) * Curves.easeInOut.transform(f);
      }
    }
    return 1;
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 120, size.height / 120);
    if (tile) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(const Rect.fromLTWH(0, 0, 120, 120), const Radius.circular(36)),
        Paint()..color = PulseBrand.logoTile,
      );
      canvas.translate(60, 60);
      canvas.scale(0.86);
      canvas.translate(-60, -60);
    }
    final s = _pump(beat);
    canvas.translate(60, 60);
    canvas.scale(s);
    canvas.translate(-60, -60);

    final cookie = polarPath(
      Rect.fromCircle(center: const Offset(60, 60), radius: 46.5),
      scallops: 12,
      depth: 4.5 / 46.5,
      rotation: spin * 2 * math.pi,
      samples: 192,
    );

    // heartbeat draw-on / hold / draw-off (40% / 35% / 25% of the loop)
    final full = heartbeatPath();
    final metric = full.computeMetrics().first;
    final len = metric.length;
    double a = 0, b = len;
    if (beat < 0.4) {
      b = len * Curves.easeOut.transform(beat / 0.4);
    } else if (beat > 0.75) {
      a = len * Curves.easeIn.transform((beat - 0.75) / 0.25);
    }
    final line = metric.extractPath(a, b);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    if (mono != null) {
      canvas.saveLayer(const Rect.fromLTWH(0, 0, 120, 120), Paint());
      canvas.drawPath(cookie, Paint()..color = mono!);
      canvas.drawPath(line, stroke..blendMode = BlendMode.clear);
      canvas.restore();
    } else {
      canvas.drawPath(cookie, Paint()..color = PulseBrand.pink);
      canvas.drawPath(line, stroke..color = PulseBrand.heartbeat);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant PulseLogoPainter old) =>
      old.spin != spin || old.beat != beat || old.tile != tile || old.mono != mono;
}
