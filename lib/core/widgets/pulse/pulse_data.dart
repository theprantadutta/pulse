import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../theme/pulse_motion.dart';
import '../../theme/pulse_shapes.dart';
import '../../theme/pulse_theme.dart';
import 'pulse_controls.dart';
import 'pulse_icons.dart';

// ---------------------------------------------------------------------------
// Numbers
// ---------------------------------------------------------------------------

/// A number with its unit on the same baseline at ~25% of the number's size
/// ("37 ms", "9.4 Mbps"). [live] slides/fades the number on change.
class PulseNumber extends StatelessWidget {
  const PulseNumber(
    this.value, {
    super.key,
    this.unit,
    this.style,
    this.unitScale = .5,
    this.color,
    this.live = false,
    this.unitGap = 2,
  });

  final String value;
  final String? unit;

  /// Defaults to [pulseNumber] (20 / 800 / wdth 110).
  final TextStyle? style;

  /// Unit size relative to the number (lists use ~.6, heroes ~.22).
  final double unitScale;
  final Color? color;
  final bool live;
  final double unitGap;

  @override
  Widget build(BuildContext context) {
    final base = (style ?? pulseNumber()).copyWith(color: color ?? style?.color ?? context.colors.onSurface);
    final size = base.fontSize ?? 20;
    final unitStyle = pulseText(math.max(11, size * unitScale), 800).copyWith(color: base.color);
    final number = live ? PulseLiveValue(value, style: base) : Text(value, style: base);
    if (unit == null) return number;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        number,
        SizedBox(width: unitGap),
        Text(unit!, style: unitStyle),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Shapes
// ---------------------------------------------------------------------------

/// Fixed brand fill + its "on" colour for shapes (DESIGN_SYSTEM.md §2.2).
enum PulseTone {
  pink,
  lavender,
  lime;

  Color fill(BuildContext context) => switch (this) {
    PulseTone.pink => context.colors.primaryFixedDim,
    PulseTone.lavender => PulseBrand.lavender,
    PulseTone.lime => PulseBrand.lime,
  };

  Color on(BuildContext context) => switch (this) {
    PulseTone.pink => context.colors.onPrimaryFixed,
    PulseTone.lavender => PulseBrand.onLavender,
    PulseTone.lime => PulseBrand.onLime,
  };
}

/// A shape in a fixed brand colour with an icon at ~50% of its size.
class PulseShapeBadge extends StatelessWidget {
  const PulseShapeBadge({
    super.key,
    required this.shape,
    required this.tone,
    this.icon,
    this.size = 40,
    this.spin,
    this.child,
  });

  final PulseShape shape;
  final PulseTone tone;
  final PulseIcons? icon;
  final double size;
  final Duration? spin;
  final Widget? child;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: PulseShapeBox(
      shape: shape,
      color: tone.fill(context),
      size: size,
      spin: spin,
      child: child ?? (icon == null ? null : PulseIcon(icon!, size: size * .5, color: tone.on(context))),
    ),
  );
}

/// A badge on a theme container instead of a brand fill (router / host rows:
/// circle tertiaryContainer, arch secondaryContainer, cookie9 primaryContainer).
class PulseContainerBadge extends StatelessWidget {
  const PulseContainerBadge({
    super.key,
    required this.shape,
    required this.icon,
    required this.color,
    required this.onColor,
    this.size = 40,
    this.spin,
  });

  final PulseShape shape;
  final PulseIcons icon;
  final Color color, onColor;
  final double size;
  final Duration? spin;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: PulseShapeBox(
      shape: shape,
      color: color,
      size: size,
      spin: spin,
      child: PulseIcon(icon, size: size * .5, color: onColor),
    ),
  );
}

/// Soft blob behind hero shapes: secondaryContainer, border-radius morph plus a
/// 30° rotation over 9 s.
class PulseMorphBlob extends StatefulWidget {
  const PulseMorphBlob({super.key, required this.size, this.color});
  final double size;
  final Color? color;

  @override
  State<PulseMorphBlob> createState() => _PulseMorphBlobState();
}

class _PulseMorphBlobState extends State<PulseMorphBlob> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: PulseMotion.morphLoop);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (PulseMotion.reduced(context)) {
      _c.stop();
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
  Widget build(BuildContext context) {
    final color = widget.color ?? context.colors.secondaryContainer;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(_c.value);
        final s = widget.size;
        Radius r(double a, double b) => Radius.elliptical(s * (a + (b - a) * t), s * (b + (a - b) * t));
        return Transform.rotate(
          angle: t * math.pi / 6,
          child: Container(
            width: s,
            height: s,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.only(
                topLeft: r(.58, .42),
                topRight: r(.42, .62),
                bottomRight: r(.55, .38),
                bottomLeft: r(.45, .6),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The hero metric: a spinning, breathing cookie12 in the hero colour with a
/// morphing blob behind it. Inside: live dot + [label], then [value] + [unit].
class PulseHeroMetric extends StatelessWidget {
  const PulseHeroMetric({
    super.key,
    required this.value,
    this.unit = 'ms',
    this.label,
    this.size = 220,
    this.live = true,
    this.paused = false,
    this.shape = PulseShape.cookie12,
    this.blob = true,
    this.tone,
    this.semanticLabel,
  });

  final String value;
  final String? unit;
  final String? label;
  final double size;

  /// Shows the blinking dot and keeps the shape spinning.
  final bool live;

  /// Stops the motion and dims the value (Ping detail "Paused").
  final bool paused;
  final PulseShape shape;
  final bool blob;

  /// Defaults to the hero accent (pink).
  final PulseTone? tone;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final tone = this.tone ?? PulseTone.pink;
    final on = tone.on(context);
    final fill = paused ? context.colors.surfaceContainerHighest : tone.fill(context);
    final fg = paused ? context.colors.onSurfaceVariant : on;
    final scaler = MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.3);
    final numberSize = size * .47;
    final shapeBox = PulseShapeBox(
      shape: shape,
      color: fill,
      size: size,
      spin: live && !paused ? PulseMotion.heroSpin : null,
      breathe: live && !paused,
      child: Padding(
        padding: EdgeInsets.all(size * .14),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (label != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (live && !paused) ...[PulseLiveDot(color: fg, size: 7), const SizedBox(width: 6)],
                    Text(label!, style: pulseText(size * .064, 700).copyWith(color: fg)),
                  ],
                ),
              MediaQuery(
                data: MediaQuery.of(context).copyWith(textScaler: scaler),
                child: PulseNumber(
                  value,
                  unit: unit,
                  live: live,
                  unitScale: .22,
                  unitGap: 3,
                  style: pulseText(numberSize, 900, wdth: 120, height: .95, tracking: -.04).copyWith(color: fg),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return Semantics(
      label: semanticLabel ?? [label, value, unit].whereType<String>().join(' '),
      liveRegion: live,
      excludeSemantics: true,
      child: SizedBox(
        width: blob ? size * 1.12 : size,
        height: blob ? size * 1.06 : size,
        child: Stack(
          alignment: Alignment.topLeft,
          children: [
            if (blob) Positioned(right: 0, bottom: 0, child: PulseMorphBlob(size: size * .78)),
            Positioned(left: 0, top: 0, child: shapeBox),
          ],
        ),
      ),
    );
  }
}

/// A shape stat (speed test "Ping 37", port scan "Open 2"): label + number
/// inside a brand shape. [motion] picks spin or the clover wobble.
enum PulseShapeMotion { none, spin, wobble }

class PulseShapeStat extends StatefulWidget {
  const PulseShapeStat({
    super.key,
    required this.shape,
    required this.tone,
    required this.label,
    required this.value,
    this.unit,
    this.size = 104,
    this.motion = PulseShapeMotion.none,
  });

  final PulseShape shape;
  final PulseTone tone;
  final String label;
  final String value;
  final String? unit;
  final double size;
  final PulseShapeMotion motion;

  @override
  State<PulseShapeStat> createState() => _PulseShapeStatState();
}

class _PulseShapeStatState extends State<PulseShapeStat> with SingleTickerProviderStateMixin {
  late final AnimationController _wobble = AnimationController(vsync: this, duration: const Duration(seconds: 4));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.motion == PulseShapeMotion.wobble && !PulseMotion.reduced(context)) {
      if (!_wobble.isAnimating) _wobble.repeat(reverse: true);
    } else {
      _wobble.stop();
    }
  }

  @override
  void dispose() {
    _wobble.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final on = widget.tone.on(context);
    final s = widget.size;
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(widget.label, style: pulseText(s * .12, 700).copyWith(color: on)),
        PulseNumber(
          widget.value,
          unit: widget.unit,
          live: true,
          unitScale: .4,
          style: pulseText(s * .3, 900, wdth: 115, height: 1).copyWith(color: on),
        ),
      ],
    );
    Widget shape = PulseShapeBox(
      shape: widget.shape,
      color: widget.tone.fill(context),
      size: s,
      spin: widget.motion == PulseShapeMotion.spin ? PulseMotion.heroSpin : null,
    );
    if (widget.motion == PulseShapeMotion.wobble) {
      shape = AnimatedBuilder(
        animation: _wobble,
        builder: (context, child) => Transform.rotate(
          angle: (Curves.easeInOut.transform(_wobble.value) * 2 - 1) * 8 * math.pi / 180,
          child: child,
        ),
        child: shape,
      );
    }
    return Semantics(
      label: '${widget.label} ${widget.value} ${widget.unit ?? ''}',
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: s,
        child: Stack(
          alignment: Alignment.center,
          children: [
            shape,
            Padding(
              padding: EdgeInsets.all(s * .14),
              child: FittedBox(fit: BoxFit.scaleDown, child: content),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pops a child in from scale .6 / −24° with the spring (shape pop).
class PulsePop extends StatelessWidget {
  const PulsePop({super.key, required this.child, this.delay = Duration.zero, this.from = .6, this.rotate = true});
  final Widget child;
  final Duration delay;
  final double from;
  final bool rotate;

  @override
  Widget build(BuildContext context) {
    if (PulseMotion.reduced(context)) return child;
    return _Delayed(
      delay: delay,
      builder: (started) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: started ? 1 : 0),
        duration: const Duration(milliseconds: 700),
        curve: PulseMotion.spring,
        builder: (context, t, child) => Opacity(
          opacity: t.clamp(0, 1),
          child: Transform.rotate(
            angle: rotate ? (1 - t) * -24 * math.pi / 180 : 0,
            child: Transform.scale(scale: from + (1 - from) * t, child: child),
          ),
        ),
        child: child,
      ),
    );
  }
}

class _Delayed extends StatefulWidget {
  const _Delayed({required this.delay, required this.builder});
  final Duration delay;
  final Widget Function(bool started) builder;

  @override
  State<_Delayed> createState() => _DelayedState();
}

class _DelayedState extends State<_Delayed> {
  bool _started = false;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(widget.delay, () {
      if (mounted) setState(() => _started = true);
    });
  }

  @override
  Widget build(BuildContext context) => widget.builder(_started);
}

// ---------------------------------------------------------------------------
// Containers and rows
// ---------------------------------------------------------------------------

/// surfaceContainer card, radius 28.
class PulseCard extends StatelessWidget {
  const PulseCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color,
    this.radius = 28,
    this.onTap,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final double radius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bg = color ?? context.colors.surfaceContainer;
    if (onTap != null) {
      return PulsePressable(
        onTap: onTap,
        radius: radius,
        color: bg,
        child: Padding(padding: padding, child: child),
      );
    }
    return Container(
      padding: padding,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(radius)),
      child: child,
    );
  }
}

/// "Other hosts", "Highlights": a section label with an optional trailing action.
class PulseSectionLabel extends StatelessWidget {
  const PulseSectionLabel(this.text, {super.key, this.trailing, this.primary = false, this.padding});
  final String text;
  final Widget? trailing;

  /// Settings-style label: 14/600 in primary.
  final bool primary;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) => Padding(
    padding: padding ?? const EdgeInsets.fromLTRB(4, 16, 0, 8),
    child: Row(
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              text,
              style: primary
                  ? context.type.titleSmall!.copyWith(color: context.colors.primary)
                  : context.type.titleMedium,
            ),
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

class _SegmentPosition extends InheritedWidget {
  const _SegmentPosition({required this.index, required this.count, required super.child});
  final int index, count;

  @override
  bool updateShouldNotify(_SegmentPosition old) => old.index != index || old.count != count;
}

/// M3 Expressive grouped list: separate containers, 3 px gaps, 24 outer and 6
/// inner corners. Each child reads its position, so pass [PulseListItem]s.
class PulseSegmentedList extends StatelessWidget {
  const PulseSegmentedList({super.key, required this.children, this.animate = true});
  final List<Widget> children;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final n = children.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < n; i++) ...[
          if (i > 0) const SizedBox(height: 3),
          _SegmentPosition(
            index: i,
            count: n,
            child: animate ? PulseEntrance(index: i, child: children[i]) : children[i],
          ),
        ],
      ],
    );
  }
}

/// A row in a [PulseSegmentedList]: 40 px lead, title 16/600, subtitle 13,
/// trailing value. [selected] makes it fully round in secondaryContainer.
class PulseListItem extends StatelessWidget {
  const PulseListItem({
    super.key,
    required this.title,
    this.subtitle,
    this.overline,
    this.leading,
    this.trailing,
    this.onTap,
    this.onLongPress,
    this.selected = false,
    this.color,
    this.minHeight = 56,
    this.padding,
    this.subtitleColor,
    this.titleStyle,
    this.subtitleMaxLines = 1,
  });

  final String title;
  final String? subtitle;

  /// Small label above the title (Network details: "Local IPv4").
  final String? overline;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool selected;

  /// Defaults to surfaceContainer (surfaceContainerHigh inside panes).
  final Color? color;
  final double minHeight;
  final EdgeInsetsGeometry? padding;
  final Color? subtitleColor;
  final TextStyle? titleStyle;
  final int subtitleMaxLines;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final pos = context.dependOnInheritedWidgetOfExactType<_SegmentPosition>();
    final radius = selected
        ? BorderRadius.circular(28)
        : pos == null
        ? BorderRadius.circular(24)
        : segmentedRadius(pos.index, pos.count);
    final bg = selected ? c.secondaryContainer : (color ?? c.surfaceContainer);
    final fg = selected ? c.onSecondaryContainer : c.onSurface;
    final sub = selected ? c.onSecondaryContainer.withValues(alpha: .85) : (subtitleColor ?? c.onSurfaceVariant);
    final body = ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight),
      child: Padding(
        padding: padding ?? EdgeInsets.fromLTRB(leading != null ? 12 : 16, 8, 16, 8),
        child: Row(
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 14)],
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (overline != null)
                    Text(overline!, style: context.type.bodySmall!.copyWith(color: sub, fontSize: 12)),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: (titleStyle ?? context.type.titleMedium)!.copyWith(color: fg),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      maxLines: subtitleMaxLines,
                      overflow: TextOverflow.ellipsis,
                      style: context.type.bodySmall!.copyWith(color: sub),
                    ),
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 12),
              DefaultTextStyle.merge(
                style: TextStyle(color: fg),
                child: IconTheme.merge(
                  data: IconThemeData(color: selected ? fg : c.onSurfaceVariant),
                  child: trailing!,
                ),
              ),
            ],
          ],
        ),
      ),
    );
    return AnimatedContainer(
      duration: PulseMotion.shapeMorph,
      curve: PulseMotion.spring,
      decoration: BoxDecoration(color: bg, borderRadius: radius),
      clipBehavior: Clip.antiAlias,
      child: onTap == null && onLongPress == null
          ? body
          : Material(
              type: MaterialType.transparency,
              child: InkWell(onTap: onTap, onLongPress: onLongPress, child: body),
            ),
    );
  }
}

/// A [PulseListItem] with a trailing M3 switch.
class PulseSwitchItem extends StatelessWidget {
  const PulseSwitchItem({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.icon,
    this.color,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final PulseIcons? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) => MergeSemantics(
    child: PulseListItem(
      title: title,
      subtitle: subtitle,
      subtitleMaxLines: 2,
      color: color,
      leading: icon == null ? null : PulseIcon(icon!, size: 22, color: context.colors.onSurfaceVariant),
      onTap: onChanged == null ? null : () => onChanged!(!value),
      trailing: Switch(value: value, onChanged: onChanged),
    ),
  );
}

/// Tiles in a row: surfaceContainerHigh, 6 px gaps, 20 outer / 6 inner corners.
class PulseStat {
  const PulseStat(this.label, this.value, {this.unit, this.color});
  final String label;
  final String value;
  final String? unit;
  final Color? color;
}

class PulseStatRow extends StatelessWidget {
  const PulseStatRow({super.key, required this.stats, this.color, this.valueSize = 20, this.vertical = false});
  final List<PulseStat> stats;
  final Color? color;
  final double valueSize;

  /// Stack the tiles in a column (Monitor's stat column).
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final n = stats.length;
    Widget tile(int i) {
      final s = stats[i];
      final radius = vertical ? segmentedRadius(i, n, outer: 20) : connectedRadius(i, n);
      return Semantics(
        label: '${s.label} ${s.value} ${s.unit ?? ''}',
        excludeSemantics: true,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 10, 12),
          decoration: BoxDecoration(color: color ?? c.surfaceContainerHigh, borderRadius: radius),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                s.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.type.labelMedium!.copyWith(color: c.onSurfaceVariant),
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: PulseNumber(
                  s.value,
                  unit: s.unit,
                  live: true,
                  unitScale: .6,
                  style: pulseNumber(valueSize),
                  color: s.color,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (vertical) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < n; i++) ...[if (i > 0) const SizedBox(height: 3), tile(i)],
        ],
      );
    }
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < n; i++) ...[if (i > 0) const SizedBox(width: 6), Expanded(child: tile(i))],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Pills
// ---------------------------------------------------------------------------

enum PulsePillTone { lime, lavender, pink, outline, inverse, primaryContainer, error, neutral }

/// Verdict / info pill. Lime = good, lavender = unstable/info, pink = attention.
class PulsePill extends StatelessWidget {
  const PulsePill(
    this.label, {
    super.key,
    this.tone = PulsePillTone.neutral,
    this.icon,
    this.height = 28,
    this.dot = false,
  });
  final String label;
  final PulsePillTone tone;
  final PulseIcons? icon;
  final double height;

  /// Leading live dot.
  final bool dot;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (Color bg, Color fg, Color? border) = switch (tone) {
      PulsePillTone.lime => (PulseBrand.lime, PulseBrand.onLime, null),
      PulsePillTone.lavender => (PulseBrand.lavender, PulseBrand.onLavender, null),
      PulsePillTone.pink => (c.primaryFixedDim, c.onPrimaryFixed, null),
      PulsePillTone.outline => (Colors.transparent, c.onSurfaceVariant, c.outline),
      PulsePillTone.inverse => (c.onPrimaryFixed, c.primaryFixedDim, null),
      PulsePillTone.primaryContainer => (c.primaryContainer, c.onPrimaryContainer, null),
      PulsePillTone.error => (c.errorContainer, c.onErrorContainer, null),
      PulsePillTone.neutral => (c.surfaceContainerHigh, c.onSurfaceVariant, null),
    };
    return Container(
      height: height,
      padding: EdgeInsets.symmetric(horizontal: height * .42),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(height / 2),
        border: border == null ? null : Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[PulseLiveDot(color: fg, size: 6), const SizedBox(width: 6)],
          if (icon != null) ...[PulseIcon(icon!, size: height * .5, color: fg), const SizedBox(width: 4)],
          Text(label, maxLines: 1, style: pulseText(height * .43, 700, wdth: 105).copyWith(color: fg)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Charts
// ---------------------------------------------------------------------------

/// Pill bar sparkline. `null` values are lost packets (a small pink dot at the
/// top). Newest on the right. Bars grow from 0 with a 25 ms stagger.
class PulseBars extends StatelessWidget {
  const PulseBars({
    super.key,
    required this.values,
    this.height = 40,
    this.max,
    this.barWidth = 6,
    this.gap = 3,
    this.color,
    this.average,
    this.semanticLabel,
    this.fill = false,
  });

  final List<double?> values;
  final double height;
  final double? max;
  final double barWidth;
  final double gap;

  /// One colour for every bar instead of latency colours.
  final Color? color;

  /// Draws a dashed average line.
  final double? average;
  final String? semanticLabel;

  /// Spread the bars across the full width (bar width becomes a maximum).
  final bool fill;

  @override
  Widget build(BuildContext context) {
    final tokens = context.pulse;
    final reduce = PulseMotion.reduced(context);
    final present = values.whereType<double>();
    final top = max ?? (present.isEmpty ? 1.0 : present.reduce(math.max) * 1.15);
    return Semantics(
      label: semanticLabel ?? _summary(),
      excludeSemantics: true,
      child: SizedBox(
        height: height,
        child: LayoutBuilder(
          builder: (context, box) {
            var w = barWidth;
            var g = gap;
            if (fill && values.isNotEmpty && box.maxWidth.isFinite) {
              final slot = box.maxWidth / values.length;
              w = math.min(barWidth, slot * .66);
              g = slot - w;
            }
            final bars = <Widget>[];
            for (var i = 0; i < values.length; i++) {
              final v = values[i];
              final Widget bar;
              if (v == null) {
                bar = Align(
                  alignment: Alignment.topCenter,
                  child: Container(
                    width: w,
                    height: w,
                    decoration: BoxDecoration(color: tokens.latSlow, shape: BoxShape.circle),
                  ),
                );
              } else {
                final h = (v / top * height).clamp(w, height).toDouble();
                final col = color ?? tokens.latencyColor(v);
                bar = Align(
                  alignment: Alignment.bottomCenter,
                  child: reduce
                      ? _bar(w, h, col)
                      : TweenAnimationBuilder<double>(
                          key: ValueKey(i),
                          tween: Tween(begin: 0, end: 1),
                          duration: PulseMotion.barGrow + Duration(milliseconds: 25 * math.min(i, 40)),
                          curve: Interval(
                            math.min(i, 40) * 25 / (600 + 25 * math.min(i, 40)),
                            1,
                            curve: PulseMotion.spring,
                          ),
                          builder: (context, t, _) => _bar(w, math.max(0, h * t), col),
                        ),
                );
              }
              bars.add(
                SizedBox(
                  width: w + (i == values.length - 1 ? 0 : g),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: SizedBox(width: w, child: bar),
                  ),
                ),
              );
            }
            return Stack(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisAlignment: fill ? MainAxisAlignment.start : MainAxisAlignment.end,
                  children: bars,
                ),
                if (average != null && top > 0)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: (average! / top * height).clamp(0, height - 1).toDouble(),
                    child: CustomPaint(
                      size: const Size(double.infinity, 1),
                      painter: _DashPainter(context.colors.onSurfaceVariant.withValues(alpha: .7)),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _bar(double w, double h, Color col) => Container(
    width: w,
    height: h,
    decoration: BoxDecoration(color: col, borderRadius: BorderRadius.circular(w)),
  );

  String _summary() {
    final present = values.whereType<double>().toList();
    if (present.isEmpty) return 'No samples yet';
    final avg = present.reduce((a, b) => a + b) / present.length;
    final max = present.reduce(math.max);
    final lost = values.length - present.length;
    return 'Last ${values.length} samples, average ${avg.round()} ms, max ${max.round()} ms'
        '${lost > 0 ? ', $lost lost' : ''}';
  }
}

class _DashPainter extends CustomPainter {
  _DashPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 8) {
      canvas.drawLine(Offset(x, 0), Offset(math.min(x + 4, size.width), 0), p);
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) => old.color != color;
}

/// Wavy linear progress. When [value] reaches 1 the whole bar turns tertiary.
class PulseWavyBar extends StatelessWidget {
  const PulseWavyBar({super.key, required this.value, this.width, this.semanticLabel});
  final double value;
  final double? width;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final done = value >= 1;
    return Semantics(
      label: semanticLabel ?? 'Progress',
      value: '${(value.clamp(0, 1) * 100).round()}%',
      excludeSemantics: true,
      child: WavyProgress(
        value: value.clamp(0, 1).toDouble(),
        size: Size(width ?? double.infinity, 14),
        activeColor: done ? context.colors.tertiary : null,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// States
// ---------------------------------------------------------------------------

/// Large flower/clover in lavender with an icon, 22/700 title, one sentence.
class PulseEmptyState extends StatelessWidget {
  const PulseEmptyState({
    super.key,
    required this.title,
    required this.message,
    this.icon = PulseIcons.check,
    this.shape = PulseShape.flower,
    this.action,
    this.size = 120,
  });

  final String title;
  final String message;
  final PulseIcons icon;
  final PulseShape shape;
  final Widget? action;
  final double size;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        PulsePop(
          child: PulseShapeBadge(
            shape: shape,
            tone: PulseTone.lavender,
            icon: icon,
            size: size,
            spin: PulseMotion.heroSpin,
          ),
        ),
        const SizedBox(height: 16),
        Text(title, textAlign: TextAlign.center, style: context.type.titleLarge),
        const SizedBox(height: 6),
        Text(
          message,
          textAlign: TextAlign.center,
          style: context.type.bodyMedium!.copyWith(color: context.colors.onSurfaceVariant),
        ),
        if (action != null) ...[const SizedBox(height: 16), action!],
      ],
    ),
  );
}

/// errorContainer banner for real failures: cause plus retry.
class PulseErrorBanner extends StatelessWidget {
  const PulseErrorBanner({super.key, required this.title, this.message, this.onRetry, this.retryLabel = 'Retry'});
  final String title;
  final String? message;
  final VoidCallback? onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        decoration: BoxDecoration(color: c.errorContainer, borderRadius: BorderRadius.circular(20)),
        child: Row(
          children: [
            PulseIcon(PulseIcons.info, size: 22, color: c.onErrorContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: context.type.titleSmall!.copyWith(color: c.onErrorContainer)),
                  if (message != null)
                    Text(message!, style: context.type.bodySmall!.copyWith(color: c.onErrorContainer)),
                ],
              ),
            ),
            if (onRetry != null)
              TextButton(
                onPressed: onRetry,
                style: TextButton.styleFrom(foregroundColor: c.onErrorContainer),
                child: Text(retryLabel),
              ),
          ],
        ),
      ),
    );
  }
}

/// Copies [text] and confirms with a snackbar.
class PulseCopyButton extends StatelessWidget {
  const PulseCopyButton({super.key, required this.text, this.label = 'Copy'});
  final String text;
  final String label;

  @override
  Widget build(BuildContext context) => PulseIconButton(
    icon: PulseIcons.copy,
    tooltip: label,
    iconSize: 20,
    onPressed: () {
      Clipboard.setData(ClipboardData(text: text));
      ScaffoldMessenger.maybeOf(context)
        ?..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Copied $text'), duration: const Duration(seconds: 2)));
    },
  );
}

/// "Hidden by Android" style value for OS-hidden data, with an info button.
class PulsePrivacyNote extends StatelessWidget {
  const PulsePrivacyNote({super.key, required this.explanation});
  final String explanation;

  @override
  Widget build(BuildContext context) => PulseIconButton(
    icon: PulseIcons.info,
    tooltip: 'Why is this hidden?',
    iconSize: 20,
    onPressed: () => showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hidden by the system'),
        content: Text(explanation),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
      ),
    ),
  );
}
