import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/wire_theme.dart';

/// Brand colourways for the bolt.
enum PulseMarkColorway {
  /// Ink bolt with a paper offset — sits on signal.
  primary,

  /// Signal bolt with a paper offset — sits on ink.
  dark,

  /// Ink bolt with a signal offset — sits on paper.
  paper,

  /// One colour, no offset.
  mono,
}

/// The six-point Pulse bolt. Straight edges only, never rotated, outlined or
/// recoloured outside the colourways. The offset copy is dropped below 32px.
class PulseMark extends StatelessWidget {
  const PulseMark({
    super.key,
    this.size = 34,
    this.colorway = PulseMarkColorway.primary,
    this.color,
    this.contained = false,
  }) : assert(size >= 16, 'The mark is never drawn below 16px.');

  /// Height of the bare mark, or the side of the square when [contained].
  final double size;
  final PulseMarkColorway colorway;

  /// Mono colour (defaults to ink).
  final Color? color;

  /// Draws the app-icon square (signal for primary, ink for dark) with the
  /// bolt at 62% of the square.
  final bool contained;

  static const _bolt = '64,4 20,58 46,58 36,96 80,40 54,40';
  static const _offset = '69,9 25,63 51,63 41,101 85,45 59,45';

  static String _hex(Color c) =>
      '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

  String _svg(WireColors w) {
    final showOffset = size >= 32 && colorway != PulseMarkColorway.mono;
    final (bolt, offset, square) = switch (colorway) {
      PulseMarkColorway.primary => (WireColors.inkBlack, WireColors.paper, w.signal),
      PulseMarkColorway.dark => (w.signal, WireColors.paper, WireColors.inkBlack),
      PulseMarkColorway.paper => (WireColors.inkBlack, w.signal, WireColors.paper),
      PulseMarkColorway.mono => (color ?? w.ink, color ?? w.ink, Colors.transparent),
    };
    final polys =
        '${showOffset ? '<polygon points="$_offset" fill="${_hex(offset)}"/>' : ''}'
        '<polygon points="$_bolt" fill="${_hex(bolt)}"/>';
    if (contained) {
      final bg = colorway == PulseMarkColorway.mono
          ? ''
          : '<rect width="104" height="104" fill="${_hex(square)}"/>';
      return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 104 104">$bg'
          '<g transform="translate(19.76 19.76) scale(0.62)">$polys</g></svg>';
    }
    return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="18 2 70 100">$polys</svg>';
  }

  @override
  Widget build(BuildContext context) {
    final w = context.wire;
    return ExcludeSemantics(
      child: SizedBox(
        height: size,
        width: contained ? size : size * 0.7,
        child: SvgPicture.string(_svg(w), fit: BoxFit.contain),
      ),
    );
  }
}

/// Mark + "PULSE" wordmark. The bolt always comes before the word.
class PulseLockup extends StatelessWidget {
  const PulseLockup({
    super.key,
    this.height = 34,
    this.colorway = PulseMarkColorway.primary,
    this.stacked = false,
    this.textColor,
  });

  final double height;
  final PulseMarkColorway colorway;
  final bool stacked;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final w = context.wire;
    final fg = textColor ??
        switch (colorway) {
          PulseMarkColorway.primary => w.onSignal,
          PulseMarkColorway.dark => WireColors.paper,
          PulseMarkColorway.paper || PulseMarkColorway.mono => w.ink,
        };
    final word = Text(
      'PULSE',
      style: WireType.display(height * 0.94, width: 75, height: 1).copyWith(color: fg),
    );
    final mark = PulseMark(size: height, colorway: colorway, color: fg);
    if (stacked) {
      return Semantics(
        label: 'Pulse',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [mark, SizedBox(height: height * 0.3), word],
        ),
      );
    }
    return Semantics(
      label: 'Pulse',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [mark, SizedBox(width: height * 0.3), word],
      ),
    );
  }
}
