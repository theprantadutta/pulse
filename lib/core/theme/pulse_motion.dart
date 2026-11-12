// Pulse — motion tokens and small reusable motion widgets.
//
// Drop into lib/theme/pulse_motion.dart.
// Rules (see DESIGN_SYSTEM.md, "Motion"):
//  * Entrances: fade + 16 px rise, 600 ms, emphasized-decelerate, 40 ms stagger.
//  * Presses: scale to 0.94 and tighten the corner radius, 200 ms, spring curve.
//  * Loops (spins, waves, sonar) are ambient: slow, low amplitude, and they stop
//    when MediaQuery.disableAnimations is true.

import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

abstract final class PulseMotion {
  // Easing (cubic-bezier equivalents of the prototype CSS)
  static const Curve spring = Cubic(0.3, 1.4, 0.5, 1.0); // overshoots ~8%
  static const Curve emphasized = Cubic(0.2, 0.0, 0.0, 1.0);
  static const Curve emphasizedDecelerate = Cubic(0.05, 0.7, 0.1, 1.0);
  static const Curve standard = Cubic(0.2, 0.0, 0.0, 1.0);

  // Durations
  static const Duration press = Duration(milliseconds: 200);
  static const Duration shapeMorph = Duration(milliseconds: 350);
  static const Duration chip = Duration(milliseconds: 450);
  static const Duration enter = Duration(milliseconds: 600);
  static const Duration barGrow = Duration(milliseconds: 600);
  static const Duration valueChange = Duration(milliseconds: 250);
  static const Duration digitRoll = Duration(milliseconds: 700); // odometer digits in live numbers
  static const Duration breathe = Duration(milliseconds: 1200);
  static const Duration waveTravel = Duration(milliseconds: 1100);
  static const Duration sonar = Duration(milliseconds: 2000);
  static const Duration heartbeat = Duration(milliseconds: 2400);
  static const Duration packetTravel = Duration(milliseconds: 2600);
  static const Duration morphLoop = Duration(seconds: 9);
  static const Duration smallSpin = Duration(seconds: 10);
  static const Duration heroSpin = Duration(seconds: 28);
  static const Duration liveTick = Duration(seconds: 1); // matches the default ping interval

  static Duration stagger(int index, {int stepMs = 40, int maxSteps = 12}) =>
      Duration(milliseconds: stepMs * index.clamp(0, maxSteps));

  // Physics springs (approximation of the M3 Expressive motion scheme).
  static final SpringDescription spatialFast = SpringDescription.withDampingRatio(mass: 1, stiffness: 800, ratio: 0.6);
  static final SpringDescription spatialDefault = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 380,
    ratio: 0.8,
  );
  static final SpringDescription spatialSlow = SpringDescription.withDampingRatio(mass: 1, stiffness: 200, ratio: 0.8);
  static final SpringDescription effects = SpringDescription.withDampingRatio(mass: 1, stiffness: 1600, ratio: 1.0);

  static bool reduced(BuildContext context) => MediaQuery.maybeDisableAnimationsOf(context) ?? false;
}

/// Fade + rise entrance with stagger. Wrap list items / cards with an [index].
class PulseEntrance extends StatefulWidget {
  const PulseEntrance({super.key, required this.child, this.index = 0, this.offset = 16, this.fromLeft = false});

  final Widget child;
  final int index;
  final double offset;
  final bool fromLeft; // tablet panes slide in from the left (10 px)

  @override
  State<PulseEntrance> createState() => _PulseEntranceState();
}

class _PulseEntranceState extends State<PulseEntrance> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: PulseMotion.enter);
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (PulseMotion.reduced(context)) {
      _c.value = 1;
    } else {
      Future<void>.delayed(PulseMotion.stagger(widget.index), () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final v = PulseMotion.emphasizedDecelerate.transform(_c.value);
        final d = (1 - v) * (widget.fromLeft ? 10 : widget.offset);
        return Opacity(
          opacity: _c.value,
          child: Transform.translate(
            offset: widget.fromLeft ? Offset(-d, 0) : Offset(0, d),
            child: Transform.scale(scale: widget.fromLeft ? 1 : 0.97 + 0.03 * v, child: child),
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// Press feedback used by every tappable surface: scale 0.94 + corner tighten.
/// Pass the resting [radius]; while pressed it animates toward 14.
class PulsePressable extends StatefulWidget {
  const PulsePressable({
    super.key,
    required this.child,
    required this.onTap,
    this.radius = 24,
    this.color,
    this.onLongPress,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double radius;
  final Color? color;

  @override
  State<PulsePressable> createState() => _PulsePressableState();
}

class _PulsePressableState extends State<PulsePressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final r = _down ? 14.0 : widget.radius;
    // Listener (raw pointers) so the visual press never competes with InkWell in the gesture arena.
    return Listener(
      onPointerDown: widget.onTap == null ? null : (_) => setState(() => _down = true),
      onPointerUp: (_) => setState(() => _down = false),
      onPointerCancel: (_) => setState(() => _down = false),
      child: AnimatedScale(
        scale: _down ? 0.94 : 1,
        duration: PulseMotion.press,
        curve: PulseMotion.spring,
        child: AnimatedContainer(
          duration: PulseMotion.shapeMorph,
          curve: PulseMotion.spring,
          decoration: BoxDecoration(color: widget.color, borderRadius: BorderRadius.circular(r)),
          clipBehavior: Clip.antiAlias,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(onTap: widget.onTap, onLongPress: widget.onLongPress, child: widget.child),
          ),
        ),
      ),
    );
  }
}

/// A live number that rolls like an odometer. Each decimal place is a wheel,
/// lined up on the decimal point: when the value changes, only the wheels whose
/// digit changes turn, all upward when the value rises and downward when it
/// falls, passing through the digits in between (12 → 13 turns just the units;
/// 9.8 → 20 rolls the tens in from blank to 2 while ".8" folds away).
/// Wheels slide without fading and widths change smoothly, so nothing pops.
/// Text that isn't a plain number ("—", "Down") cross-fades instead.
class PulseLiveValue extends StatefulWidget {
  const PulseLiveValue(this.text, {super.key, this.style});

  final String text;
  final TextStyle? style;

  @override
  State<PulseLiveValue> createState() => _PulseLiveValueState();
}

/// "prefix 12.5 suffix" split for the odometer; null when [s] isn't numeric.
class _Num {
  _Num(this.prefix, this.whole, this.fraction, this.suffix);

  static final _re = RegExp(r'^([^0-9]*?)(\d+)(?:\.(\d+))?([^0-9]*)$');

  static _Num? parse(String s) {
    final m = _re.firstMatch(s);
    if (m == null) return null;
    return _Num(m[1]!, m[2]!, m[3] ?? '', m[4]!);
  }

  final String prefix;
  final String whole;
  final String fraction;
  final String suffix;

  double get value => double.parse(fraction.isEmpty ? whole : '$whole.$fraction');

  /// Digit at [place] (0 = units, -1 = tenths), or null when not shown.
  int? digit(int place) {
    if (place >= 0) {
      if (place >= whole.length) return null;
      return whole.codeUnitAt(whole.length - 1 - place) - 48;
    }
    final k = -place - 1;
    if (k >= fraction.length) return null;
    return fraction.codeUnitAt(k) - 48;
  }
}

class _PulseLiveValueState extends State<PulseLiveValue> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: PulseMotion.digitRoll, value: 1);
  late final _t = CurvedAnimation(parent: _c, curve: Curves.easeInOutCubic);
  late String _from = widget.text;

  @override
  void didUpdateWidget(PulseLiveValue old) {
    super.didUpdateWidget(old);
    if (old.text == widget.text) return;
    _from = old.text;
    if (PulseMotion.reduced(context)) {
      _c.value = 1;
    } else {
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _t.dispose();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = DefaultTextStyle.of(context).style.merge(widget.style);
    return Semantics(
      label: widget.text,
      excludeSemantics: true,
      child: AnimatedBuilder(animation: _t, builder: (context, _) => _frame(style, _t.value)),
    );
  }

  Widget _frame(TextStyle style, double t) {
    final to = _Num.parse(widget.text);
    final from = t >= 1 ? to : _Num.parse(_from);
    if (to == null || from == null || from.prefix != to.prefix || from.suffix != to.suffix) {
      // Not two comparable numbers: cross-fade the whole text.
      return Stack(
        alignment: AlignmentDirectional.centerStart,
        children: [
          if (t < 1)
            Opacity(
              opacity: 1 - t,
              child: Text(_from, style: style),
            ),
          Opacity(
            opacity: t,
            child: Text(widget.text, style: style),
          ),
        ],
      );
    }
    final up = to.value >= from.value;
    final top = math.max(from.whole.length, to.whole.length) - 1;
    final bottom = -math.max(from.fraction.length, to.fraction.length);
    double presence(bool a, bool b) => (a ? 1.0 : 0.0) + ((b ? 1.0 : 0.0) - (a ? 1.0 : 0.0)) * t;
    final dot = presence(from.fraction.isNotEmpty, to.fraction.isNotEmpty);
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        if (to.prefix.isNotEmpty) Text(to.prefix, style: style),
        for (var place = top; place >= bottom; place--) ...[
          if (place == -1 && dot > 0)
            _Fold(
              factor: dot,
              child: Text('.', style: style),
            ),
          _wheelAt(place, from, to, up, t, style, presence),
        ],
        if (to.suffix.isNotEmpty) Text(to.suffix, style: style),
      ],
    );
  }

  Widget _wheelAt(
    int place,
    _Num from,
    _Num to,
    bool up,
    double t,
    TextStyle style,
    double Function(bool, bool) presence,
  ) {
    final a = from.digit(place), b = to.digit(place);
    final da = a ?? 0, db = b ?? 0;
    // Turn the shorter way consistent with the value's direction.
    final steps = up ? (db - da) % 10 : -((da - db) % 10);
    final width = presence(a != null, b != null);
    // A missing leading integer digit reads as blank, not 0.
    final blankZero = place > 0 && (a == null || b == null);
    final fraction = place < 0 && (a == null || b == null);
    Widget wheel = _Wheel(position: da + steps * t, blankZero: blankZero, style: style);
    if (fraction) wheel = Opacity(opacity: width.clamp(0.0, 1.0), child: wheel);
    return _Fold(factor: width, child: wheel);
  }
}

/// Collapses a child horizontally (1 = full width, 0 = gone).
class _Fold extends StatelessWidget {
  const _Fold({required this.factor, required this.child});

  final double factor;
  final Widget child;

  @override
  Widget build(BuildContext context) => ClipRect(
    child: Align(alignment: Alignment.centerRight, widthFactor: factor.clamp(0.0, 1.0), child: child),
  );
}

/// One odometer wheel showing a continuous [position] (2.5 = halfway from 2
/// to 3). Always the same widget tree, so it never flickers between frames.
class _Wheel extends StatelessWidget {
  const _Wheel({required this.position, required this.blankZero, required this.style});

  final double position;
  final bool blankZero;
  final TextStyle style;

  String _glyph(int d) => blankZero && d == 0 ? ' ' : '$d';

  @override
  Widget build(BuildContext context) {
    final base = position.floorToDouble();
    final frac = position - base;
    final lower = base.toInt() % 10;
    final upper = (lower + 1) % 10;
    return ClipRect(
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Sizes the wheel and carries the baseline.
          Opacity(opacity: 0, child: Text('0', style: style)),
          FractionalTranslation(
            translation: Offset(0, -frac),
            child: Text(_glyph(lower), style: style),
          ),
          FractionalTranslation(
            translation: Offset(0, 1 - frac),
            child: Text(_glyph(upper), style: style),
          ),
        ],
      ),
    );
  }
}

/// Blinking live dot (1.4 s).
class PulseLiveDot extends StatefulWidget {
  const PulseLiveDot({super.key, this.color, this.size = 8});

  final Color? color;
  final double size;

  @override
  State<PulseLiveDot> createState() => _PulseLiveDotState();
}

class _PulseLiveDotState extends State<PulseLiveDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (PulseMotion.reduced(context)) {
      _c.stop();
      _c.value = 0;
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? DefaultTextStyle.of(context).style.color ?? Theme.of(context).colorScheme.tertiary;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        final o = t < 0.5 ? 1 - 1.4 * t : 0.3 + 1.4 * (t - 0.5);
        return Opacity(
          opacity: o.clamp(0.3, 1.0),
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        );
      },
    );
  }
}
