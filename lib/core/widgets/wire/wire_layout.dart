import 'package:material_ui/material_ui.dart';

import '../../brand/pulse_mark.dart';
import '../../theme/wire_theme.dart';
import 'wire_box.dart';
import 'wire_button.dart';
import 'wire_pressable.dart';

/// Inverse strip label (e.g. RECENT TARGETS, APPEARANCE).
class WireSectionBar extends StatelessWidget {
  const WireSectionBar(
    this.label, {
    super.key,
    this.trailing,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
  });

  final String label;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final w = context.wire;
    final style = WireType.label().copyWith(color: w.background);
    return Container(
      color: w.ink,
      padding: padding,
      child: DefaultTextStyle(
        style: style,
        child: Row(
          children: [
            Expanded(child: Text(label.toUpperCase())),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

/// A column definition for [WireTableHeader] / [WireTableRow].
@immutable
class WireCol {
  const WireCol(this.label, {this.flex, this.width, this.align = TextAlign.left});
  final String label;
  final int? flex;
  final double? width;
  final TextAlign align;
}

/// Inverse header row for tables.
class WireTableHeader extends StatelessWidget {
  const WireTableHeader({
    super.key,
    required this.columns,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
    this.gap = 12,
  });

  final List<WireCol> columns;
  final EdgeInsetsGeometry padding;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final w = context.wire;
    return Container(
      color: w.ink,
      padding: padding,
      child: WireColumns(
        columns: columns,
        gap: gap,
        cells: [
          for (final c in columns)
            Text(
              c.label.toUpperCase(),
              textAlign: c.align,
              maxLines: 1,
              overflow: TextOverflow.clip,
              style: WireType.label().copyWith(color: w.background),
            ),
        ],
      ),
    );
  }
}

/// Lays [cells] out using [columns] widths/flexes.
class WireColumns extends StatelessWidget {
  const WireColumns({
    super.key,
    required this.columns,
    required this.cells,
    this.gap = 12,
    this.crossAxisAlignment = CrossAxisAlignment.center,
  });

  final List<WireCol> columns;
  final List<Widget> cells;
  final double gap;
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var i = 0; i < columns.length; i++) {
      if (i > 0) children.add(SizedBox(width: gap));
      final c = columns[i];
      final cell = Align(
        alignment: c.align == TextAlign.right
            ? Alignment.centerRight
            : c.align == TextAlign.center
            ? Alignment.center
            : Alignment.centerLeft,
        child: cells[i],
      );
      children.add(
        c.width != null
            ? SizedBox(width: c.width, child: cell)
            : Expanded(flex: c.flex ?? 1, child: cell),
      );
    }
    return Row(crossAxisAlignment: crossAxisAlignment, children: children);
  }
}

/// Mobile screen header: 48px, ink fill + paper title, or signal fill.
class WireMobileHeader extends StatelessWidget {
  const WireMobileHeader({
    super.key,
    required this.title,
    this.onBack,
    this.trailing,
    this.signal = false,
  });

  final String title;
  final VoidCallback? onBack;
  final Widget? trailing;
  final bool signal;

  @override
  Widget build(BuildContext context) {
    final w = context.wire;
    final bg = signal ? w.signal : w.ink;
    final fg = signal ? w.onSignal : w.background;
    return Container(
      height: WireLayout.mobileHeader,
      decoration: BoxDecoration(
        color: bg,
        border: Border(bottom: BorderSide(color: w.ink, width: kWireBorder)),
      ),
      child: Row(
        children: [
          if (onBack != null)
            WirePressable(
              onTap: onBack,
              tone: signal ? WireTone.signal : WireTone.ink,
              semanticLabel: 'Back',
              builder: (context, c, s) => Container(
                color: c.bg,
                width: WireLayout.minHit,
                height: WireLayout.mobileHeader,
                alignment: Alignment.center,
                child: Text('←', style: WireType.title(26).copyWith(color: c.fg)),
              ),
            )
          else
            const SizedBox(width: 14),
          Expanded(
            child: Text(
              title.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: WireType.title(26).copyWith(color: fg),
            ),
          ),
          if (trailing != null)
            WireForeground(
              color: fg,
              child: DefaultTextStyle.merge(
                style: WireType.label(12),
                child: trailing!,
              ),
            ),
          const SizedBox(width: 14),
        ],
      ),
    );
  }
}

/// Top-bar chip (e.g. COUNT ∞, INT 1.0s). Tappable when [onTap] is set.
class WireTopChip extends StatelessWidget {
  const WireTopChip({
    super.key,
    required this.label,
    this.onTap,
    this.selected = false,
  });

  final String label;
  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return WireCell(
      onTap: onTap,
      selected: selected,
      sides: WireSides.onlyRight,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      alignment: Alignment.center,
      child: Text(label, style: WireType.body(13)),
    );
  }
}

/// Small bordered tag: GATEWAY, THIS DEVICE, NEW, WI-FI 6, …
class WireTag extends StatelessWidget {
  const WireTag(this.label, {super.key, this.tone = WireTone.plain, this.dense = false});

  final String label;
  final WireTone tone;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final w = context.wire;
    final c = wireRestColors(w, tone);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 5 : 8, vertical: dense ? 1 : 3),
      decoration: BoxDecoration(
        color: c.bg,
        border: Border.all(color: w.ink, width: dense ? 1 : kWireBorder),
      ),
      child: Text(
        label.toUpperCase(),
        style: WireType.label(dense ? 9 : 11).copyWith(color: c.fg),
      ),
    );
  }
}

/// Terminal-style target input: `TARGET>` prefix, mono 700 value,
/// signal caret, white surface while editing.
class WireTargetField extends StatelessWidget {
  const WireTargetField({
    super.key,
    required this.controller,
    this.prefix = 'TARGET>',
    this.hint = 'host or IP',
    this.onSubmitted,
    this.onChanged,
    this.focusNode,
    this.enabled = true,
    this.fontSize = 20,
    this.trailing,
    this.editing = false,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final String prefix;
  final String hint;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final FocusNode? focusNode;
  final bool enabled;
  final double fontSize;
  final Widget? trailing;

  /// Shows the white input surface.
  final bool editing;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final w = context.wire;
    return Container(
      color: editing ? w.surfaceInput : null,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Text(prefix, style: WireType.label(12).copyWith(color: w.ink)),
          const SizedBox(width: 16),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              enabled: enabled,
              autofocus: autofocus,
              onSubmitted: onSubmitted,
              onChanged: onChanged,
              autocorrect: false,
              enableSuggestions: false,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.go,
              cursorColor: w.signal,
              cursorWidth: fontSize * 0.55,
              cursorHeight: fontSize * 1.1,
              cursorRadius: Radius.zero,
              style: WireType.data(fontSize).copyWith(color: w.ink),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: WireType.data(fontSize).copyWith(color: w.text3),
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                isCollapsed: true,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Plain bordered text input for forms (filters, ports, names).
class WireInput extends StatelessWidget {
  const WireInput({
    super.key,
    required this.controller,
    this.hint,
    this.onChanged,
    this.onSubmitted,
    this.keyboardType,
    this.width,
    this.prefix,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final String? hint;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputType? keyboardType;
  final double? width;
  final String? prefix;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final w = context.wire;
    return SizedBox(
      width: width,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        keyboardType: keyboardType,
        autofocus: autofocus,
        autocorrect: false,
        cursorColor: w.signal,
        cursorRadius: Radius.zero,
        cursorWidth: 7,
        style: WireType.data(13).copyWith(color: w.ink),
        decoration: InputDecoration(
          hintText: hint,
          prefixText: prefix,
          prefixStyle: WireType.label(11).copyWith(color: w.ink),
        ),
      ),
    );
  }
}

/// Big condensed headline + one mono line + a primary action.
class WireEmptyState extends StatelessWidget {
  const WireEmptyState({
    super.key,
    required this.title,
    required this.message,
    this.actionLabel,
    this.actionGlyph = '▶',
    this.onAction,
    this.compact = false,
  });

  final String title;
  final String message;
  final String? actionLabel;
  final String actionGlyph;
  final VoidCallback? onAction;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final w = context.wire;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PulseMark(size: compact ? 40 : 64, colorway: PulseMarkColorway.mono, color: w.text3),
            const SizedBox(height: 16),
            Text(
              title.toUpperCase(),
              style: WireType.display(compact ? 40 : 64, width: 66).copyWith(color: w.ink),
            ),
            const SizedBox(height: 10),
            Text(message, style: WireType.body(13).copyWith(color: w.text2)),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              WireButton(
                label: actionLabel!,
                glyph: actionGlyph,
                variant: WireButtonVariant.primary,
                onPressed: onAction,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Replaces a hero on failure: UNREACHABLE on signal tint + mono reason.
class WireErrorBlock extends StatelessWidget {
  const WireErrorBlock({
    super.key,
    required this.reason,
    this.title = 'UNREACHABLE',
    this.size = 96,
    this.onRetry,
  });

  final String reason;
  final String title;
  final double size;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final w = context.wire;
    return Container(
      color: w.signalTint,
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(title, style: WireType.display(size, width: 64).copyWith(color: w.ink)),
          ),
          const SizedBox(height: 10),
          Text(reason, style: WireType.body(13).copyWith(color: w.ink)),
          if (onRetry != null) ...[
            const SizedBox(height: 14),
            WireButton(label: 'RETRY', glyph: '↻', onPressed: onRetry, height: 40, fontSize: 16),
          ],
        ],
      ),
    );
  }
}

/// Key/value row with an optional COPY button (Network tables).
class WireKeyValueRow extends StatelessWidget {
  const WireKeyValueRow({
    super.key,
    required this.label,
    required this.value,
    this.copy = true,
    this.valueColor,
    this.onTap,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
  });

  final String label;
  final String value;
  final bool copy;
  final Color? valueColor;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final w = context.wire;
    return WireRow(
      onTap: onTap,
      padding: padding,
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(label.toUpperCase(), style: WireType.label().copyWith(color: w.text2)),
          ),
          Expanded(
            child: SelectableText(
              value,
              maxLines: 1,
              style: WireType.data(14).copyWith(color: valueColor ?? w.ink),
            ),
          ),
          if (copy) ...[
            const SizedBox(width: 10),
            WireCopyButton(value: () => value),
          ],
        ],
      ),
    );
  }
}
