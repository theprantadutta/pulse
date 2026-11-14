import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/widgets/pulse/pulse.dart';
import '../../../services/update_checker.dart';
import 'settings_screen.dart' show packageInfoProvider;

/// A segmented group whose items get their corner radius from their position.
/// [PulseListItem]s read it themselves; custom containers use the argument.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, required this.items});
  final List<Widget Function(BorderRadius radius)> items;

  @override
  Widget build(BuildContext context) => PulseSegmentedList(
    animate: false,
    children: [for (var i = 0; i < items.length; i++) items[i](segmentedRadius(i, items.length))],
  );
}

/// A settings row: icon, title (+ optional subtitle) and the current value in
/// primary, a chevron, or (destructive) an outlined button. Tap opens a picker.
class SettingsValueItem extends StatelessWidget {
  const SettingsValueItem({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.value,
    this.onTap,
    this.chevron = false,
    this.destructive = false,
  });

  final PulseIcons icon;
  final String title;
  final String? subtitle;
  final String? value;
  final VoidCallback? onTap;
  final bool chevron;

  /// Shows an outlined (never pink) action button; [onTap] confirms first.
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final enabled = onTap != null;
    final Widget? trailing = destructive
        ? PulseButton(label: 'Clear', style: PulseButtonStyle.outlined, size: PulseButtonSize.small, onPressed: onTap)
        : value != null && value!.isNotEmpty
        ? ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 160),
            child: Text(
              value!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: pulseText(15, 700).copyWith(color: enabled ? c.primary : c.onSurfaceVariant),
            ),
          )
        : chevron
        ? PulseIcon(PulseIcons.chevR, size: 20, color: c.onSurfaceVariant)
        : null;
    return MergeSemantics(
      child: PulseListItem(
        minHeight: subtitle == null ? 56 : 64,
        leading: PulseIcon(icon, size: 22, color: c.onSurfaceVariant),
        title: title,
        titleStyle: subtitle == null ? context.type.titleMedium!.copyWith(fontWeight: FontWeight.w500) : null,
        subtitle: subtitle,
        subtitleMaxLines: 2,
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }
}

/// Phone Appearance: "Theme" title above the Light · Dark · System group.
class ThemeGroupItem extends StatelessWidget {
  const ThemeGroupItem({super.key, required this.radius, required this.selected, required this.onChanged});
  final BorderRadius radius;
  final ThemeMode selected;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
      decoration: BoxDecoration(color: c.surfaceContainer, borderRadius: radius),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Row(
              children: [
                PulseIcon(PulseIcons.palette, size: 22, color: c.onSurfaceVariant),
                const SizedBox(width: 14),
                Text('Theme', style: context.type.titleMedium),
              ],
            ),
          ),
          const SizedBox(height: 10),
          PulseButtonGroup<ThemeMode>(
            segments: const [
              PulseSegment(ThemeMode.light, 'Light', icon: PulseIcons.sun),
              PulseSegment(ThemeMode.dark, 'Dark', icon: PulseIcons.moon),
              PulseSegment(ThemeMode.system, 'System', icon: PulseIcons.auto),
            ],
            selected: selected,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

/// Phone Appearance: "Accent" title above the four shapes.
class AccentItem extends StatelessWidget {
  const AccentItem({super.key, required this.radius, required this.picker, required this.dimmed});
  final BorderRadius radius;
  final Widget picker;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(color: c.surfaceContainer, borderRadius: radius),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Accent', style: context.type.titleMedium),
          if (dimmed)
            Text('Off while Dynamic color is on', style: context.type.bodySmall!.copyWith(color: c.onSurfaceVariant)),
          const SizedBox(height: 10),
          picker,
        ],
      ),
    );
  }
}

/// The four accents as shapes: pink cookie12, lavender clover4, lime sunny,
/// blue flower. Selected spins slowly and shows a check in its "on" colour.
class AccentPicker extends StatelessWidget {
  const AccentPicker({super.key, required this.selected, required this.onChanged, this.enabled = true});
  final String selected;
  final ValueChanged<String> onChanged;
  final bool enabled;

  static const _shapes = [PulseShape.cookie12, PulseShape.clover4, PulseShape.sunny, PulseShape.flower];

  @override
  Widget build(BuildContext context) {
    final current = PulseAccent.of(selected);
    return Opacity(
      opacity: enabled ? 1 : .38,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < PulseAccent.values.length; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            _AccentButton(
              accent: PulseAccent.values[i],
              shape: _shapes[i],
              selected: PulseAccent.values[i] == current,
              onTap: enabled ? () => onChanged(PulseAccent.values[i].key) : null,
            ),
          ],
        ],
      ),
    );
  }
}

class _AccentButton extends StatelessWidget {
  const _AccentButton({required this.accent, required this.shape, required this.selected, required this.onTap});
  final PulseAccent accent;
  final PulseShape shape;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: '${accent.label} accent',
    child: Semantics(
      button: true,
      selected: selected,
      enabled: onTap != null,
      label: '${accent.label} accent',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox.square(
          dimension: 52,
          child: Center(
            child: AnimatedScale(
              scale: selected ? 1 : .92,
              duration: PulseMotion.shapeMorph,
              curve: PulseMotion.spring,
              child: PulseShapeBox(
                shape: shape,
                color: accent.fixedDim,
                size: 52,
                spin: selected ? PulseMotion.smallSpin * 2 : null,
                child: selected ? PulseIcon(PulseIcons.check, size: 22, color: accent.onFixed) : null,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Tablet Appearance: three theme preview cards (mini UI: cookie + two bars;
/// System is split light / dark). The selected card uses secondaryContainer.
class ThemePreviewRow extends StatelessWidget {
  const ThemePreviewRow({super.key, required this.selected, required this.onChanged});
  final ThemeMode selected;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    const modes = [(ThemeMode.light, 'Light'), (ThemeMode.dark, 'Dark'), (ThemeMode.system, 'System')];
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < modes.length; i++) ...[
            if (i > 0) const SizedBox(width: 16),
            Expanded(
              child: PulseEntrance(
                index: i,
                child: _ThemeCard(
                  mode: modes[i].$1,
                  label: modes[i].$2,
                  selected: selected == modes[i].$1,
                  onTap: () => onChanged(modes[i].$1),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ThemeCard extends StatelessWidget {
  const _ThemeCard({required this.mode, required this.label, required this.selected, required this.onTap});
  final ThemeMode mode;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fg = selected ? c.onSecondaryContainer : c.onSurface;
    Widget half(ColorScheme s) => Expanded(
      child: Container(
        color: s.surface,
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PulseShapeBox(shape: PulseShape.cookie12, color: c.primaryFixedDim, size: 44),
            const SizedBox(height: 8),
            _Bar(width: .7, color: s.onSurface),
            const SizedBox(height: 6),
            _Bar(width: .45, color: s.outlineVariant),
          ],
        ),
      ),
    );
    return Semantics(
      button: true,
      selected: selected,
      label: '$label theme',
      excludeSemantics: true,
      child: PulsePressable(
        onTap: onTap,
        radius: 28,
        color: selected ? c.secondaryContainer : c.surfaceContainer,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: 120,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: c.outlineVariant),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: switch (mode) {
                    ThemeMode.light => [half(pulseLightScheme)],
                    ThemeMode.dark => [half(pulseDarkScheme)],
                    ThemeMode.system => [half(pulseLightScheme), half(pulseDarkScheme)],
                  },
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 0, 6, 4),
                child: Row(
                  children: [
                    if (selected) ...[PulseIcon(PulseIcons.check, size: 18, color: fg), const SizedBox(width: 8)],
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: pulseText(15, 700).copyWith(color: fg),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.width, required this.color});
  final double width;
  final Color color;

  @override
  Widget build(BuildContext context) => FractionallySizedBox(
    widthFactor: width,
    alignment: Alignment.centerLeft,
    child: Container(
      height: 8,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
    ),
  );
}

/// Tablet categories pane row (56 dp; selected: secondaryContainer, round).
class SettingsCategoryItem extends StatelessWidget {
  const SettingsCategoryItem({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final PulseIcons icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fg = selected ? c.onSecondaryContainer : c.onSurface;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: PulsePressable(
        onTap: onTap,
        radius: selected ? 28 : 16,
        color: selected ? c.secondaryContainer : Colors.transparent,
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              PulseIcon(icon, size: 22, color: fg),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.type.bodyLarge!.copyWith(
                    color: fg,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Logo tile, "Pulse 1.0.0", "Apache-2.0 · Made with Flutter", Check for updates.
class AboutCard extends ConsumerWidget {
  const AboutCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final version = ref.watch(packageInfoProvider).value?.version;
    final info = Row(
      children: [
        const PulseLogo(size: 44, tile: true),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(version == null ? 'Pulse' : 'Pulse $version', style: context.type.titleMedium),
              Text(
                'Apache-2.0 · Made with Flutter',
                style: context.type.bodySmall!.copyWith(color: c.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
    return Container(
      // On phones the text button's own tap area already pads the bottom.
      padding: EdgeInsets.fromLTRB(16, 14, 8, context.isCompact ? 4 : 14),
      decoration: BoxDecoration(color: c.surfaceContainer, borderRadius: BorderRadius.circular(24)),
      // Phones: the button goes under the name so it never truncates. (No
      // LayoutBuilder: the tablet footer sits in a SliverFillRemaining, which
      // measures intrinsics.)
      child: context.isCompact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                info,
                const Align(alignment: Alignment.centerRight, child: UpdateCheckButton()),
              ],
            )
          : Row(
              children: [
                Expanded(child: info),
                const UpdateCheckButton(),
              ],
            ),
    );
  }
}

/// "Check for updates" against the latest GitHub release; when a newer one
/// exists the button opens its page.
class UpdateCheckButton extends StatefulWidget {
  const UpdateCheckButton({super.key});

  @override
  State<UpdateCheckButton> createState() => _UpdateCheckButtonState();
}

class _UpdateCheckButtonState extends State<UpdateCheckButton> {
  String? _status;
  UpdateInfo? _info;
  bool _busy = false;

  Future<void> _check() async {
    if (_info?.newer == true) {
      await openExternalLink(context, _info!.url);
      return;
    }
    setState(() => _busy = true);
    try {
      final current = (await PackageInfo.fromPlatform()).version;
      final info = await const UpdateChecker().check(current);
      if (!mounted) return;
      setState(() {
        _info = info;
        _status = info.newer ? 'Get v${info.latest}' : 'Up to date';
      });
    } on Object {
      if (mounted) setState(() => _status = 'Check failed, retry');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PulseButton(
    label: _busy ? 'Checking…' : _status ?? 'Check for updates',
    style: PulseButtonStyle.text,
    size: PulseButtonSize.small,
    onPressed: _busy ? null : _check,
  );
}

/// Bottom-sheet picker for a settings value; returns the chosen option.
Future<T?> pickSetting<T>(
  BuildContext context, {
  required String title,
  String? message,
  required List<(T, String)> options,
  required T current,
}) {
  final c = context.colors;
  return showModalBottomSheet<T>(
    useRootNavigator: true,
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: c.surfaceContainerLow,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
              child: Text(title, style: context.type.titleLarge),
            ),
            if (message != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                child: Text(message, style: context.type.bodyMedium!.copyWith(color: c.onSurfaceVariant)),
              ),
            Flexible(
              child: SingleChildScrollView(
                child: PulseSegmentedList(
                  animate: false,
                  children: [
                    for (final (value, label) in options)
                      PulseListItem(
                        title: label,
                        selected: value == current,
                        color: c.surfaceContainerHigh,
                        trailing: value == current ? const PulseIcon(PulseIcons.check, size: 20) : null,
                        onTap: () => Navigator.pop(context, value),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Confirm dialog for destructive actions (never pink; the action is a text
/// button in the error colour).
Future<bool> confirmDestructive(
  BuildContext context, {
  required String title,
  required String body,
  required String action,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          style: TextButton.styleFrom(foregroundColor: context.colors.error),
          child: Text(action),
        ),
      ],
    ),
  );
  return ok ?? false;
}
