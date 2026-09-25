import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/widgets/wire/wire.dart';

/// Desktop top bar for single-target tools: TARGET> field, option chips
/// and a run/stop button.
class ToolTargetBar extends StatelessWidget {
  const ToolTargetBar({
    super.key,
    required this.controller,
    required this.onRun,
    required this.running,
    this.subtitle,
    this.chips = const [],
    this.runLabel = 'Run',
    this.runGlyph = '▶',
    this.onStop,
    this.hint = 'host or IP',
    this.runVariant = WireButtonVariant.primary,
  });

  final TextEditingController controller;
  final VoidCallback onRun;
  final VoidCallback? onStop;
  final bool running;
  final String? subtitle;
  final List<Widget> chips;
  final String runLabel;
  final String runGlyph;
  final String hint;
  final WireButtonVariant runVariant;

  @override
  Widget build(BuildContext context) {
    final w = context.wire;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: WireTargetField(
            controller: controller,
            hint: hint,
            enabled: !running,
            onSubmitted: (_) => onRun(),
            trailing: subtitle == null
                ? null
                : Text(subtitle!, style: WireType.body(13).copyWith(color: w.text3)),
          ),
        ),
        const WireVRule(),
        ...chips,
        if (running && onStop != null)
          WireButton(
            label: 'Stop',
            glyph: '■',
            variant: WireButtonVariant.inverse,
            bordered: false,
            fontSize: 17,
            height: WireLayout.topBar,
            padding: const EdgeInsets.symmetric(horizontal: 28),
            onPressed: onStop,
          )
        else
          WireButton(
            label: runLabel,
            glyph: runGlyph,
            variant: runVariant,
            bordered: false,
            busy: running,
            fontSize: 17,
            height: WireLayout.topBar,
            padding: const EdgeInsets.symmetric(horizontal: 28),
            onPressed: running ? null : onRun,
          ),
      ],
    );
  }
}

/// A top-bar chip that cycles through [values] on tap.
class CycleChip<T> extends StatelessWidget {
  const CycleChip({
    super.key,
    required this.values,
    required this.value,
    required this.label,
    required this.onChanged,
    this.enabled = true,
  });

  final List<T> values;
  final T value;
  final String Function(T v) label;
  final ValueChanged<T> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return WireTopChip(
      label: label(value),
      onTap: enabled
          ? () {
              final i = values.indexOf(value);
              onChanged(values[(i + 1) % values.length]);
            }
          : null,
    );
  }
}

/// Mobile TARGET> row.
class MobileTargetRow extends StatelessWidget {
  const MobileTargetRow({
    super.key,
    required this.controller,
    required this.onSubmitted,
    this.enabled = true,
    this.trailing,
    this.hint = 'host or IP',
  });

  final TextEditingController controller;
  final ValueChanged<String> onSubmitted;
  final bool enabled;
  final Widget? trailing;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final w = context.wire;
    return Container(
      height: 50,
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: w.ink, width: kWireBorder))),
      child: WireTargetField(
        controller: controller,
        fontSize: 17,
        hint: hint,
        enabled: enabled,
        onSubmitted: onSubmitted,
        trailing: trailing,
      ),
    );
  }
}

/// ← back for pushed tool screens on mobile.
VoidCallback? mobileBack(BuildContext context) =>
    GoRouter.maybeOf(context)?.canPop() == true ? () => context.pop() : null;

/// Two-button action footer (COPY / SAVE, EXPORT / …).
class PanelActions extends StatelessWidget {
  const PanelActions({super.key, required this.actions});
  final List<({String label, VoidCallback? onTap, bool primary})> actions;

  @override
  Widget build(BuildContext context) {
    final w = context.wire;
    return Container(
      decoration: BoxDecoration(border: Border(top: BorderSide(color: w.ink, width: kWireBorder))),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < actions.length; i++)
              Expanded(
                child: WireButton(
                  label: actions[i].label,
                  variant: actions[i].primary ? WireButtonVariant.primary : WireButtonVariant.outline,
                  bordered: false,
                  sides: i < actions.length - 1 ? WireSides.onlyRight : WireSides.none,
                  fontSize: 16,
                  height: 52,
                  onPressed: actions[i].onTap,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
