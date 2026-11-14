import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../../core/widgets/pulse/pulse.dart';

/// The clover wobble (DESIGN_SYSTEM.md §10): rotates [child] by ±8° over 4 s,
/// ease-in-out, reversing. Rests at 0° when motion is reduced or when
/// [active] is false (the scan finished), so nothing keeps looking busy.
class ShapeWobble extends StatefulWidget {
  const ShapeWobble({super.key, required this.child, this.active = true});
  final Widget child;
  final bool active;

  @override
  State<ShapeWobble> createState() => _ShapeWobbleState();
}

class _ShapeWobbleState extends State<ShapeWobble> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 4), value: .5);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(ShapeWobble old) {
    super.didUpdateWidget(old);
    if (old.active != widget.active) _sync();
  }

  void _sync() {
    if (PulseMotion.reduced(context)) {
      _c
        ..stop()
        ..value = .5;
    } else if (!widget.active) {
      // Settle back to upright instead of freezing mid-tilt.
      _c.animateTo(.5, duration: const Duration(milliseconds: 500), curve: Curves.easeOut);
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (context, child) =>
        Transform.rotate(angle: (Curves.easeInOut.transform(_c.value) * 2 - 1) * 8 * math.pi / 180, child: child),
    child: widget.child,
  );
}
