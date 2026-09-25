import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../theme/wire_theme.dart';
import 'wire_box.dart';
import 'wire_pressable.dart';

enum WireButtonVariant {
  /// Signal fill — START / SCAN / SAVE.
  primary,

  /// Ink fill — ■ STOP, secondary strong actions.
  inverse,

  /// Transparent with a 2px ink border.
  outline,
}

/// Wire button: Archivo 800 / wdth 80, uppercase, square, 2px border.
class WireButton extends StatelessWidget {
  const WireButton({
    super.key,
    required this.label,
    this.onPressed,
    this.glyph,
    this.variant = WireButtonVariant.outline,
    this.height = 48,
    this.fontSize = 18,
    this.expand = false,
    this.bordered = true,
    this.sides,
    this.padding = const EdgeInsets.symmetric(horizontal: 20),
    this.tooltip,
    this.busy = false,
  });

  /// Full-width bottom action bar (56px), e.g. mobile ■ STOP.
  const WireButton.bar({
    super.key,
    required this.label,
    this.onPressed,
    this.glyph,
    this.variant = WireButtonVariant.primary,
    this.tooltip,
    this.busy = false,
    this.sides = WireSides.none,
  }) : height = WireLayout.actionBar,
       fontSize = 20,
       expand = true,
       bordered = false,
       padding = const EdgeInsets.symmetric(horizontal: 20);

  final String label;
  final VoidCallback? onPressed;

  /// A geometric glyph shown before the label: ▶ ■ ↻ ← ✓ ▲.
  final String? glyph;
  final WireButtonVariant variant;
  final double height;
  final double fontSize;
  final bool expand;
  final bool bordered;

  /// Overrides [bordered] with specific edges.
  final WireSides? sides;
  final EdgeInsetsGeometry padding;
  final String? tooltip;

  /// Shows a running indicator in place of the glyph.
  final bool busy;

  WireTone get _tone => switch (variant) {
    WireButtonVariant.primary => WireTone.signal,
    WireButtonVariant.inverse => WireTone.ink,
    WireButtonVariant.outline => WireTone.plain,
  };

  @override
  Widget build(BuildContext context) {
    final w = context.wire;
    final edges = sides ?? (bordered ? WireSides.all : WireSides.none);
    return WirePressable(
      onTap: onPressed,
      tone: _tone,
      tooltip: tooltip,
      semanticLabel: label,
      builder: (context, c, states) {
        final text = [if (glyph != null && !busy) glyph!, label.toUpperCase()]
            .join(' ');
        return Container(
          height: height,
          width: expand ? double.infinity : null,
          padding: padding,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: c.bg,
            border: edges.toBorder(w.ink, kWireBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (busy) ...[
                WireBusyGlyph(color: c.fg, size: fontSize * 0.6),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: WireType.nav(fontSize).copyWith(color: c.fg),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// A square that steps through four positions — the mechanical "working"
/// indicator used in buttons (no spinning circles).
class WireBusyGlyph extends StatefulWidget {
  const WireBusyGlyph({super.key, required this.color, this.size = 12});
  final Color color;
  final double size;

  @override
  State<WireBusyGlyph> createState() => _WireBusyGlyphState();
}

class _WireBusyGlyphState extends State<WireBusyGlyph> {
  int _step = 0;
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(
      const Duration(milliseconds: 160),
      (_) => setState(() => _step = (_step + 1) % 4),
    );
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    final half = s / 2;
    const positions = [Offset(0, 0), Offset(1, 0), Offset(1, 1), Offset(0, 1)];
    final p = positions[_step];
    return SizedBox(
      width: s,
      height: s,
      child: Stack(
        children: [
          Positioned(
            left: p.dx * half,
            top: p.dy * half,
            child: Container(width: half, height: half, color: widget.color),
          ),
        ],
      ),
    );
  }
}

/// Segmented control: 2px border, equal cells split by 2px rules,
/// active cell inverse.
class WireSegmented<T> extends StatelessWidget {
  const WireSegmented({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.height = 44,
    this.textStyle,
    this.bordered = true,
    this.enabled = true,
  });

  final List<(T, String)> options;
  final T selected;
  final ValueChanged<T>? onChanged;
  final double height;
  final TextStyle? textStyle;
  final bool bordered;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final w = context.wire;
    final style = textStyle ?? WireType.label(12);
    final cells = <Widget>[];
    for (var i = 0; i < options.length; i++) {
      final (value, label) = options[i];
      if (i > 0) cells.add(Container(width: kWireBorder, color: w.ink));
      cells.add(
        Expanded(
          child: WirePressable(
            selected: value == selected,
            onTap: enabled && onChanged != null ? () => onChanged!(value) : null,
            semanticLabel: label,
            builder: (context, c, states) => Container(
              color: c.bg,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.fade,
                softWrap: false,
                style: style.copyWith(color: c.fg),
              ),
            ),
          ),
        ),
      );
    }
    return Container(
      height: height,
      decoration: bordered
          ? BoxDecoration(border: Border.all(color: w.ink, width: kWireBorder))
          : null,
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: cells),
    );
  }
}

/// Square switch: 2px border; on = ink track + signal knob.
class WireToggle extends StatelessWidget {
  const WireToggle({
    super.key,
    required this.value,
    required this.onChanged,
    this.semanticLabel,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final w = context.wire;
    return Semantics(
      toggled: value,
      label: semanticLabel,
      child: WirePressable(
        onTap: onChanged == null ? null : () => onChanged!(!value),
        builder: (context, c, states) => ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: WireLayout.minHit,
            minHeight: WireLayout.minHit,
          ),
          child: Center(
            child: Container(
              width: 48,
              height: 26,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: value
                    ? w.ink
                    : states.contains(WidgetState.hovered)
                    ? w.signalTint
                    : Colors.transparent,
                border: Border.all(color: w.ink, width: kWireBorder),
              ),
              child: AnimatedAlign(
                duration: WireMotion.bars,
                curve: Curves.linear,
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 18,
                  height: 18,
                  color: onChanged == null
                      ? w.text3
                      : value
                      ? w.signal
                      : w.ink,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bordered COPY button; writes to the clipboard and reads COPIED for 1.2s.
class WireCopyButton extends StatefulWidget {
  const WireCopyButton({
    super.key,
    required this.value,
    this.label = 'COPY',
    this.bordered = true,
    this.height = 32,
    this.fontSize = 12,
  });

  final String Function() value;
  final String label;
  final bool bordered;
  final double height;
  final double fontSize;

  @override
  State<WireCopyButton> createState() => _WireCopyButtonState();
}

class _WireCopyButtonState extends State<WireCopyButton> {
  bool _copied = false;
  Timer? _timer;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.value()));
    if (!mounted) return;
    _timer?.cancel();
    setState(() => _copied = true);
    _timer = Timer(WireMotion.copied, () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = context.wire;
    return WirePressable(
      onTap: _copy,
      selected: _copied,
      semanticLabel: widget.label,
      builder: (context, c, states) => ConstrainedBox(
        constraints: const BoxConstraints(minWidth: WireLayout.minHit),
        child: Container(
          height: widget.height,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: c.bg,
            border: widget.bordered
                ? Border.all(color: w.ink, width: kWireBorder)
                : null,
          ),
          child: Text(
            _copied ? 'COPIED' : widget.label,
            style: WireType.label(widget.fontSize).copyWith(color: c.fg),
          ),
        ),
      ),
    );
  }
}
