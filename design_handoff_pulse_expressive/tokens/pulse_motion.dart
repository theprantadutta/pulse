// Pulse — motion tokens and small reusable motion widgets.
//
// Drop into lib/theme/pulse_motion.dart.
// Rules (see DESIGN_SYSTEM.md, "Motion"):
//  * Entrances: fade + 16 px rise, 600 ms, emphasized-decelerate, 40 ms stagger.
//  * Presses: scale to 0.94 and tighten the corner radius, 200 ms, spring curve.
//  * Loops (spins, waves, sonar) are ambient: slow, low amplitude, and they stop
//    when MediaQuery.disableAnimations is true.

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

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
  static final SpringDescription spatialDefault = SpringDescription.withDampingRatio(mass: 1, stiffness: 380, ratio: 0.8);
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
  const PulsePressable({super.key, required this.child, required this.onTap, this.radius = 24, this.color, this.onLongPress});

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

/// A number that slides/fades when it changes (live latency values).
class PulseLiveValue extends StatelessWidget {
  const PulseLiveValue(this.text, {super.key, this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: PulseMotion.reduced(context) ? Duration.zero : PulseMotion.valueChange,
      switchInCurve: PulseMotion.emphasizedDecelerate,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero).animate(anim),
          child: child,
        ),
      ),
      layoutBuilder: (current, previous) => Stack(alignment: Alignment.centerLeft, children: <Widget>[...previous, if (current != null) current]),
      child: Text(text, key: ValueKey<String>(text), style: style),
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
          child: Container(width: widget.size, height: widget.size, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        );
      },
    );
  }
}
