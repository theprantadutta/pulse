import 'package:material_ui/material_ui.dart';

import '../../theme/wire_theme.dart';
import 'wire_pressable.dart';

/// Which edges of a Wire container draw an ink border. Grids share edges, so
/// most cells only draw right and/or bottom.
@immutable
class WireSides {
  const WireSides({this.top = false, this.right = false, this.bottom = false, this.left = false});

  final bool top, right, bottom, left;

  static const all = WireSides(top: true, right: true, bottom: true, left: true);
  static const none = WireSides();
  static const onlyTop = WireSides(top: true);
  static const onlyRight = WireSides(right: true);
  static const onlyBottom = WireSides(bottom: true);
  static const onlyLeft = WireSides(left: true);
  static const rightBottom = WireSides(right: true, bottom: true);
  static const horizontal = WireSides(top: true, bottom: true);
  static const vertical = WireSides(left: true, right: true);

  Border toBorder(Color color, double width) {
    BorderSide s(bool on) => on ? BorderSide(color: color, width: width) : BorderSide.none;
    return Border(top: s(top), right: s(right), bottom: s(bottom), left: s(left));
  }
}

/// A static container on the 2px ink grid. Radius is always zero; the only
/// shadow allowed is the hard offset (desktop cards, settings swatches).
class WireBox extends StatelessWidget {
  const WireBox({
    super.key,
    this.child,
    this.sides = WireSides.all,
    this.color,
    this.borderColor,
    this.borderWidth = kWireBorder,
    this.padding,
    this.width,
    this.height,
    this.alignment,
    this.shadowOffset,
    this.shadowColor,
    this.clip = false,
  });

  final Widget? child;
  final WireSides sides;
  final Color? color;
  final Color? borderColor;
  final double borderWidth;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? height;
  final AlignmentGeometry? alignment;

  /// Hard, blur-free offset shadow, e.g. `Offset(12, 12)`.
  final Offset? shadowOffset;
  final Color? shadowColor;
  final bool clip;

  @override
  Widget build(BuildContext context) {
    final w = context.wire;
    return Container(
      width: width,
      height: height,
      alignment: alignment,
      padding: padding,
      clipBehavior: clip ? Clip.hardEdge : Clip.none,
      decoration: BoxDecoration(
        color: color,
        border: sides.toBorder(borderColor ?? w.ink, borderWidth),
        boxShadow: shadowOffset == null
            ? null
            : [BoxShadow(color: shadowColor ?? w.ink, offset: shadowOffset!, blurRadius: 0)],
      ),
      child: child,
    );
  }
}

/// An interactive grid cell: hover → tint, pressed/selected → inverse.
class WireCell extends StatelessWidget {
  const WireCell({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.selected = false,
    this.tone = WireTone.plain,
    this.sides = WireSides.none,
    this.padding = const EdgeInsets.symmetric(horizontal: 18),
    this.alignment = Alignment.centerLeft,
    this.minHeight,
    this.width,
    this.height,
    this.tooltip,
    this.semanticLabel,
  });

  /// Rendered inside a [DefaultTextStyle]/[IconTheme] carrying the state
  /// foreground colour, so plain [Text] children follow hover/press.
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool selected;
  final WireTone tone;
  final WireSides sides;
  final EdgeInsetsGeometry padding;
  final AlignmentGeometry alignment;
  final double? minHeight;
  final double? width;
  final double? height;
  final String? tooltip;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final w = context.wire;
    return WirePressable(
      onTap: onTap,
      onLongPress: onLongPress,
      selected: selected,
      tone: tone,
      tooltip: tooltip,
      semanticLabel: semanticLabel,
      builder: (context, c, states) => Container(
        width: width,
        height: height,
        constraints: minHeight == null ? null : BoxConstraints(minHeight: minHeight!),
        alignment: alignment,
        padding: padding,
        decoration: BoxDecoration(color: c.bg, border: sides.toBorder(w.ink, kWireBorder)),
        child: WireForeground(color: c.fg, child: child),
      ),
    );
  }
}

/// Pushes a foreground colour to descendant text and icons.
class WireForeground extends StatelessWidget {
  const WireForeground({super.key, required this.color, required this.child});
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle.merge(
      style: TextStyle(color: color),
      child: IconTheme.merge(
        data: IconThemeData(color: color),
        child: child,
      ),
    );
  }
}

/// Highlight states for list rows.
enum WireRowHighlight { none, tint, muted }

/// A list row with a 1px ink hairline underneath.
class WireRow extends StatelessWidget {
  const WireRow({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.highlight = WireRowHighlight.none,
    this.selected = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    this.divider = kWireHairline,
    this.minHeight = WireLayout.minHit,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final WireRowHighlight highlight;

  /// Selected rows use the signal tint (not the inverse used by nav).
  final bool selected;
  final EdgeInsetsGeometry padding;

  /// Bottom border width; 0 for none.
  final double divider;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final w = context.wire;
    final tone = selected || highlight == WireRowHighlight.tint
        ? WireTone.tint
        : highlight == WireRowHighlight.muted
        ? WireTone.muted
        : WireTone.plain;
    Widget build(WireStateColors c) => Container(
      constraints: BoxConstraints(minHeight: minHeight),
      padding: padding,
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: c.bg,
        border: divider > 0
            ? Border(
                bottom: BorderSide(color: w.ink, width: divider),
              )
            : null,
      ),
      child: WireForeground(color: c.fg, child: child),
    );
    if (onTap == null && onLongPress == null) {
      return build(wireRestColors(w, tone));
    }
    return WirePressable(onTap: onTap, onLongPress: onLongPress, tone: tone, builder: (context, c, states) => build(c));
  }
}

/// Lays children side by side separated by 2px ink rules. Needs a bounded
/// height (or wraps in [IntrinsicHeight] when [intrinsic] is true).
class WireSplitRow extends StatelessWidget {
  const WireSplitRow({
    super.key,
    required this.children,
    this.flex,
    this.intrinsic = true,
    this.ruleWidth = kWireBorder,
  });

  final List<Widget> children;

  /// Flex factor per child; a null entry sizes the child to its content.
  final List<int?>? flex;
  final bool intrinsic;
  final double ruleWidth;

  @override
  Widget build(BuildContext context) {
    final w = context.wire;
    final items = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) items.add(Container(width: ruleWidth, color: w.ink));
      final f = flex == null ? 1 : flex![i];
      items.add(f == null ? children[i] : Expanded(flex: f, child: children[i]));
    }
    final row = Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: items);
    return intrinsic ? IntrinsicHeight(child: row) : row;
  }
}

/// A 2px horizontal ink rule.
class WireRule extends StatelessWidget {
  const WireRule({super.key, this.width = kWireBorder, this.color});
  final double width;
  final Color? color;

  @override
  Widget build(BuildContext context) => Container(height: width, color: color ?? context.wire.ink);
}

/// A 2px vertical ink rule.
class WireVRule extends StatelessWidget {
  const WireVRule({super.key, this.width = kWireBorder, this.color});
  final double width;
  final Color? color;

  @override
  Widget build(BuildContext context) => Container(width: width, color: color ?? context.wire.ink);
}
