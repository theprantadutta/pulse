import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../theme/wire_theme.dart';

/// Resting fill of an interactive Wire surface.
enum WireTone {
  /// Transparent on paper; hover → signal tint, pressed/selected → inverse.
  plain,

  /// Signal fill (primary action).
  signal,

  /// Ink fill (inverse action, e.g. ■ STOP).
  ink,

  /// Signal tint (selected / warning row).
  tint,

  /// Muted row (timeout / disabled / this device).
  muted,
}

/// Background/foreground pair resolved for the current interaction state.
@immutable
class WireStateColors {
  const WireStateColors(this.bg, this.fg);
  final Color bg;
  final Color fg;
}

WireStateColors wireRestColors(WireColors w, WireTone tone) {
  switch (tone) {
    case WireTone.plain:
      return WireStateColors(Colors.transparent, w.ink);
    case WireTone.signal:
      return WireStateColors(w.signal, w.onSignal);
    case WireTone.ink:
      return WireStateColors(w.ink, w.background);
    case WireTone.tint:
      return WireStateColors(w.signalTint, w.ink);
    case WireTone.muted:
      return WireStateColors(w.mutedRow, w.ink);
  }
}

/// Resolves Wire's state rules:
/// hover → signal tint, pressed or selected → inverse, disabled → text3.
WireStateColors wireStateColors(WireColors w, WireTone tone, Set<WidgetState> states) {
  final rest = wireRestColors(w, tone);
  if (states.contains(WidgetState.disabled)) {
    // Signal means "actionable", so a disabled primary drops its fill.
    final bg = tone == WireTone.signal || tone == WireTone.ink ? w.mutedRow : rest.bg;
    return WireStateColors(bg, w.text3);
  }
  if (states.contains(WidgetState.pressed)) {
    return tone == WireTone.ink ? WireStateColors(w.background, w.ink) : WireStateColors(w.ink, w.background);
  }
  if (states.contains(WidgetState.selected)) {
    return WireStateColors(w.ink, w.background);
  }
  if (states.contains(WidgetState.hovered)) {
    switch (tone) {
      case WireTone.signal:
        return WireStateColors(Color.lerp(w.signal, w.onSignal, 0.14)!, w.onSignal);
      case WireTone.ink:
        return WireStateColors(Color.lerp(w.ink, w.background, 0.2)!, w.background);
      case WireTone.plain:
      case WireTone.tint:
      case WireTone.muted:
        return WireStateColors(w.signalTint, w.ink);
    }
  }
  return rest;
}

typedef WireStateWidgetBuilder = Widget Function(BuildContext context, WireStateColors colors, Set<WidgetState> states);

/// The one interactive building block behind every Wire button, row, cell,
/// nav item and chip. Handles hover, press, keyboard focus and activation.
class WirePressable extends StatefulWidget {
  const WirePressable({
    super.key,
    required this.builder,
    this.onTap,
    this.onLongPress,
    this.tone = WireTone.plain,
    this.selected = false,
    this.focusNode,
    this.autofocus = false,
    this.semanticLabel,
    this.tooltip,
  });

  final WireStateWidgetBuilder builder;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final WireTone tone;
  final bool selected;
  final FocusNode? focusNode;
  final bool autofocus;
  final String? semanticLabel;
  final String? tooltip;

  @override
  State<WirePressable> createState() => _WirePressableState();
}

class _WirePressableState extends State<WirePressable> {
  bool _hovered = false;
  bool _pressed = false;
  bool _focused = false;

  bool get _enabled => widget.onTap != null || widget.onLongPress != null;

  Set<WidgetState> get _states => {
    if (!_enabled) WidgetState.disabled,
    if (_hovered && _enabled) WidgetState.hovered,
    if (_pressed && _enabled) WidgetState.pressed,
    if (_focused) WidgetState.focused,
    if (widget.selected) WidgetState.selected,
  };

  @override
  Widget build(BuildContext context) {
    final w = context.wire;
    final states = _states;
    final colors = wireStateColors(w, widget.tone, states);

    Widget child = widget.builder(context, colors, states);
    if (_focused) {
      child = CustomPaint(foregroundPainter: _FocusOutlinePainter(w.signal), child: child);
    }

    child = FocusableActionDetector(
      enabled: _enabled,
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      mouseCursor: _enabled ? SystemMouseCursors.click : MouseCursor.defer,
      onShowHoverHighlight: (v) => setState(() => _hovered = v),
      onShowFocusHighlight: (v) => setState(() => _focused = v),
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onTap?.call();
            return null;
          },
        ),
      },
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: _enabled ? (_) => setState(() => _pressed = false) : null,
        onTapCancel: _enabled ? () => setState(() => _pressed = false) : null,
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: child,
      ),
    );

    child = Semantics(button: _enabled, selected: widget.selected, label: widget.semanticLabel, child: child);
    if (widget.tooltip != null) {
      child = Tooltip(message: widget.tooltip!, child: child);
    }
    return child;
  }
}

/// 2px signal outline, offset 2px outside the widget bounds.
class _FocusOutlinePainter extends CustomPainter {
  _FocusOutlinePainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = kWireBorder;
    canvas.drawRect((Offset.zero & size).inflate(3), paint);
  }

  @override
  bool shouldRepaint(_FocusOutlinePainter old) => old.color != color;
}
