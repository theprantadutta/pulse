import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../theme/pulse_motion.dart';
import '../../theme/pulse_theme.dart';
import 'pulse_icons.dart';

enum PulseButtonStyle {
  /// Fixed brand pink (primaryFixedDim / onPrimaryFixed): the one primary
  /// action per screen (Stop, Run again, Scan, Start).
  pink,

  /// secondaryContainer: secondary actions (Cancel test, Pause all).
  tonal,

  /// surfaceContainerHigh: quiet actions next to a pink one.
  neutral,

  /// Outlined: destructive or low-emphasis actions (never pink).
  outlined,

  /// Text only, primary colour.
  text,
}

enum PulseButtonSize {
  small(40, 16, 18),
  medium(48, 20, 18),
  large(56, 24, 20);

  const PulseButtonSize(this.height, this.padding, this.icon);
  final double height, padding, icon;
}

({Color bg, Color fg, Color? border}) _buttonColors(BuildContext context, PulseButtonStyle style) {
  final c = context.colors;
  return switch (style) {
    PulseButtonStyle.pink => (bg: c.primaryFixedDim, fg: c.onPrimaryFixed, border: null),
    PulseButtonStyle.tonal => (bg: c.secondaryContainer, fg: c.onSecondaryContainer, border: null),
    PulseButtonStyle.neutral => (bg: c.surfaceContainerHigh, fg: c.onSurface, border: null),
    PulseButtonStyle.outlined => (bg: Colors.transparent, fg: c.onSurface, border: c.outlineVariant),
    PulseButtonStyle.text => (bg: Colors.transparent, fg: c.primary, border: null),
  };
}

/// Stadium button with the expressive press morph (scale .94, corners → 14).
class PulseButton extends StatelessWidget {
  const PulseButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.style = PulseButtonStyle.pink,
    this.size = PulseButtonSize.medium,
    this.expand = false,
    this.tooltip,
  });

  final String label;
  final VoidCallback? onPressed;
  final PulseIcons? icon;
  final PulseButtonStyle style;
  final PulseButtonSize size;

  /// Fill the available width.
  final bool expand;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final colors = _buttonColors(context, style);
    final enabled = onPressed != null;
    final fg = enabled ? colors.fg : context.colors.onSurface.withValues(alpha: .38);
    final bg = enabled || colors.bg == Colors.transparent ? colors.bg : context.colors.onSurface.withValues(alpha: .10);
    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[PulseIcon(icon!, size: size.icon, color: fg), const SizedBox(width: 8)],
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: (size == PulseButtonSize.large ? context.type.titleMedium : context.type.labelLarge)!.copyWith(
              color: fg,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
    Widget button = Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: PulsePressable(
        onTap: onPressed,
        radius: size.height / 2,
        color: bg,
        child: Container(
          height: size.height,
          constraints: BoxConstraints(minWidth: size.height),
          padding: EdgeInsets.symmetric(horizontal: size.padding),
          decoration: colors.border == null
              ? null
              : BoxDecoration(
                  border: Border.all(color: colors.border!),
                  borderRadius: BorderRadius.circular(size.height / 2),
                ),
          // Only fill when asked: in a Wrap, Row or empty state a centred
          // Container would otherwise stretch to every pixel it is offered.
          alignment: expand ? Alignment.center : null,
          child: content,
        ),
      ),
    );
    if (tooltip != null) button = Tooltip(message: tooltip!, child: button);
    return button;
  }
}

enum PulseIconButtonStyle { standard, tonal, pink, neutral }

/// Icon-only button: 48 dp target, [visualSize] dp disc. Always has a tooltip.
class PulseIconButton extends StatelessWidget {
  const PulseIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.style = PulseIconButtonStyle.standard,
    this.visualSize = 40,
    this.iconSize = 22,
    this.color,
  });

  final PulseIcons icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final PulseIconButtonStyle style;
  final double visualSize;
  final double iconSize;

  /// Overrides the icon colour (standard style only).
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (Color bg, Color fg) = switch (style) {
      PulseIconButtonStyle.standard => (Colors.transparent, color ?? c.onSurfaceVariant),
      PulseIconButtonStyle.tonal => (c.secondaryContainer, c.onSecondaryContainer),
      PulseIconButtonStyle.neutral => (c.surfaceContainerHigh, c.onSurface),
      PulseIconButtonStyle.pink => (c.primaryFixedDim, c.onPrimaryFixed),
    };
    final enabled = onPressed != null;
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: tooltip,
        excludeSemantics: true,
        child: SizedBox.square(
          dimension: visualSize < 48 ? 48 : visualSize,
          child: Center(
            child: PulsePressable(
              onTap: onPressed,
              radius: visualSize / 2,
              color: bg,
              child: SizedBox.square(
                dimension: visualSize,
                child: Center(
                  child: PulseIcon(icon, size: iconSize, color: enabled ? fg : fg.withValues(alpha: .38)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Extended FAB: 60 tall, radius 20, pink, 18 px icon + 16/800 label.
class PulseFab extends StatelessWidget {
  const PulseFab({super.key, required this.label, required this.icon, required this.onPressed});
  final String label;
  final PulseIcons icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: dark ? const Color(0x61000000) : const Color(0x2E46142D),
              blurRadius: dark ? 24 : 22,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: PulsePressable(
          onTap: onPressed,
          radius: 20,
          color: c.primaryFixedDim,
          child: Container(
            height: 60,
            padding: const EdgeInsets.only(left: 18, right: 22),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                PulseIcon(icon, size: 18, color: c.onPrimaryFixed),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: context.type.titleMedium!.copyWith(fontWeight: FontWeight.w800, color: c.onPrimaryFixed),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Filter chip: 40 tall (32 small), radius 12 with an outlineVariant border.
/// Selected: no border, secondaryContainer, radius 20, leading check.
class PulseChip extends StatelessWidget {
  const PulseChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
    this.small = false,
    this.icon,
    this.showCheck = true,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final bool small;
  final PulseIcons? icon;
  final bool showCheck;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fg = selected ? c.onSecondaryContainer : c.onSurfaceVariant;
    final radius = selected ? 20.0 : 12.0;
    final lead = selected && showCheck ? PulseIcons.check : icon;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: SizedBox(
        height: small ? 40 : 48,
        child: Center(
          widthFactor: 1,
          child: PulsePressable(
            onTap: onTap,
            radius: radius,
            color: selected ? c.secondaryContainer : Colors.transparent,
            child: AnimatedContainer(
              duration: PulseMotion.shapeMorph,
              curve: PulseMotion.spring,
              height: small ? 32 : 40,
              padding: EdgeInsets.only(left: lead != null ? 10 : 14, right: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(radius),
                border: selected ? null : Border.all(color: c.outlineVariant),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (lead != null) ...[PulseIcon(lead, size: 16, color: fg), const SizedBox(width: 6)],
                  Text(
                    label,
                    style: context.type.bodyMedium!.copyWith(
                      color: fg,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Horizontally scrolling chip row with 8 dp gaps that bleeds to the screen edge.
class PulseChipRow extends StatelessWidget {
  const PulseChipRow({super.key, required this.children, this.padding = EdgeInsets.zero});
  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    padding: padding,
    child: Row(
      children: [
        for (var i = 0; i < children.length; i++) ...[if (i > 0) const SizedBox(width: 8), children[i]],
      ],
    ),
  );
}

class PulseSegment<T> {
  const PulseSegment(this.value, this.label, {this.icon, this.done = false, this.trailing});
  final T value;
  final String label;
  final PulseIcons? icon;

  /// Completed step: shows a check and tertiary text (speed test phases).
  final bool done;

  /// Extra text after the label (e.g. "37" in "✓ Ping 37").
  final String? trailing;
}

/// M3 Expressive connected button group: 3 px seams, 24 outer / 8 inner
/// corners. The selected button grows to flex 1.35, turns fully round and pink.
class PulseButtonGroup<T> extends StatelessWidget {
  const PulseButtonGroup({
    super.key,
    required this.segments,
    required this.selected,
    this.onChanged,
    this.small = false,
  });

  final List<PulseSegment<T>> segments;
  final T? selected;
  final ValueChanged<T>? onChanged;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final h = small ? 40.0 : 48.0;
    final n = segments.length;
    return SizedBox(
      height: h,
      child: Row(
        children: [
          for (var i = 0; i < n; i++) ...[
            if (i > 0) const SizedBox(width: 3),
            _GroupButton<T>(
              segment: segments[i],
              selected: segments[i].value == selected,
              height: h,
              radius: segments[i].value == selected
                  ? BorderRadius.circular(h / 2)
                  : BorderRadius.horizontal(
                      left: Radius.circular(i == 0 ? 24 : 8),
                      right: Radius.circular(i == n - 1 ? 24 : 8),
                    ),
              colors: c,
              onTap: onChanged == null ? null : () => onChanged!(segments[i].value),
            ),
          ],
        ],
      ),
    );
  }
}

class _GroupButton<T> extends StatelessWidget {
  const _GroupButton({
    required this.segment,
    required this.selected,
    required this.height,
    required this.radius,
    required this.colors,
    required this.onTap,
  });

  final PulseSegment<T> segment;
  final bool selected;
  final double height;
  final BorderRadius radius;
  final ColorScheme colors;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final reduce = PulseMotion.reduced(context);
    final fg = selected
        ? colors.onPrimaryFixed
        : segment.done
        ? colors.tertiary
        : colors.onSurfaceVariant;
    final icon = segment.done && !selected ? PulseIcons.check : segment.icon;
    return TweenAnimationBuilder<double>(
      tween: Tween(end: selected ? 135 : 100),
      duration: reduce ? Duration.zero : PulseMotion.shapeMorph,
      curve: PulseMotion.spring,
      builder: (context, flex, child) => Expanded(flex: flex.round().clamp(1, 1000), child: child!),
      child: Semantics(
        button: true,
        selected: selected,
        label: segment.label,
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap == null
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  onTap!();
                },
          child: AnimatedContainer(
            duration: reduce ? Duration.zero : PulseMotion.shapeMorph,
            curve: PulseMotion.spring,
            height: height,
            decoration: BoxDecoration(
              color: selected ? colors.primaryFixedDim : colors.surfaceContainerHigh,
              borderRadius: radius,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            alignment: Alignment.center,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[PulseIcon(icon, size: 16, color: fg), const SizedBox(width: 6)],
                  Text(
                    segment.trailing == null ? segment.label : '${segment.label} ${segment.trailing}',
                    style: context.type.labelLarge!.copyWith(color: fg),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 56 dp stadium target field in surfaceContainerHigh: search icon, value
/// 17/600 and trailing auxiliary text (resolved IP, duration).
class PulseTargetField extends StatelessWidget {
  const PulseTargetField({
    super.key,
    required this.controller,
    this.hint = 'Host or IP',
    this.trailing,
    this.trailingWidget,
    this.onSubmitted,
    this.enabled = true,
    this.focusNode,
    this.icon = PulseIcons.search,
    this.keyboardType = TextInputType.url,
    this.autofocus = false,
    this.onChanged,
    this.fillColor,
  });

  final TextEditingController controller;
  final String hint;
  final String? trailing;
  final Widget? trailingWidget;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final bool enabled;
  final FocusNode? focusNode;
  final PulseIcons icon;
  final TextInputType keyboardType;
  final bool autofocus;

  /// Background; defaults to surfaceContainerHigh. Dialogs (which are that
  /// colour themselves) pass surfaceContainerHighest so the field shows.
  final Color? fillColor;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final style = context.type.titleMedium!.copyWith(fontSize: 17);
    return Container(
      height: 56,
      padding: const EdgeInsets.only(left: 16, right: 20),
      decoration: BoxDecoration(color: fillColor ?? c.surfaceContainerHigh, borderRadius: BorderRadius.circular(28)),
      child: Row(
        children: [
          PulseIcon(icon, size: 22, color: c.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              enabled: enabled,
              autofocus: autofocus,
              keyboardType: keyboardType,
              textInputAction: TextInputAction.go,
              autocorrect: false,
              enableSuggestions: false,
              onSubmitted: onSubmitted,
              onChanged: onChanged,
              style: style.copyWith(color: c.onSurface),
              cursorColor: c.primary,
              decoration: InputDecoration.collapsed(
                hintText: hint,
                hintStyle: style.copyWith(color: c.onSurfaceVariant, fontWeight: FontWeight.w500),
              ),
            ),
          ),
          if (trailingWidget != null)
            trailingWidget!
          else if (trailing != null)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(trailing!, style: context.type.bodySmall!.copyWith(color: c.onSurfaceVariant)),
            ),
        ],
      ),
    );
  }
}
