import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/widgets/pulse/pulse.dart';
import '../../../providers/alerts_provider.dart';
import '../../../providers/monitor_provider.dart';
import '../../../services/background/monitor_engine.dart';

/// Badge for a rule's metric (same family as the incident badges).
class RuleBadge extends StatelessWidget {
  const RuleBadge({super.key, required this.metric, this.size = 40, this.muted = false});
  final String metric;
  final double size;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final (shape, tone, icon) = switch (metric) {
      AlertMetric.latency => (PulseShape.sunny, PulseTone.lavender, PulseIcons.timer),
      AlertMetric.loss => (PulseShape.clover4, PulseTone.lavender, PulseIcons.loss),
      AlertMetric.down => (PulseShape.burst, PulseTone.pink, PulseIcons.power),
      _ => (PulseShape.pill, PulseTone.lime, PulseIcons.lan),
    };
    if (muted) {
      return PulseContainerBadge(
        shape: shape,
        icon: icon,
        color: context.colors.surfaceContainerHighest,
        onColor: context.colors.onSurfaceVariant,
        size: size,
      );
    }
    return PulseShapeBadge(shape: shape, tone: tone, icon: icon, size: size);
  }
}

String metricLabel(String metric) => switch (metric) {
  AlertMetric.latency => 'Latency',
  AlertMetric.loss => 'Loss',
  AlertMetric.down => 'Down',
  AlertMetric.newDevice => 'New device',
  _ => metric,
};

/// The tray channel puts the alert in the desktop tray, and on Android in the
/// ongoing "Pulse · monitoring" notification. iOS has neither.
String get trayChannelLabel => Platform.isAndroid ? 'Status' : 'Tray';

/// "Push + tray".
String channelsLabel(int channels) {
  final parts = [
    if (channels & AlertChannel.push != 0) 'Push',
    if (channels & AlertChannel.tray != 0 && !Platform.isIOS) trayChannelLabel,
    if (channels & AlertChannel.sound != 0) 'Sound',
  ];
  if (parts.isEmpty) return 'No channel';
  return [parts.first, ...parts.skip(1).map((p) => p.toLowerCase())].join(' + ');
}

/// Rule editor: name, watch (host / any target), when (metric), threshold,
/// for at least, notify via. Save validates; Delete asks first.
class RuleEditor extends ConsumerStatefulWidget {
  const RuleEditor({super.key, required this.draft, required this.onDone, this.compact = false});
  final RuleDraft draft;
  final VoidCallback onDone;

  /// Full-page editor on phones (buttons pinned at the bottom).
  final bool compact;

  @override
  ConsumerState<RuleEditor> createState() => _RuleEditorState();
}

class _RuleEditorState extends ConsumerState<RuleEditor> {
  late RuleDraft _d = widget.draft;
  late final _title = TextEditingController(text: widget.draft.title);
  late final _host = TextEditingController(text: widget.draft.target == '*' ? '' : widget.draft.target);
  String? _error;
  bool _saving = false;

  static final _hostPattern = RegExp(r'^[A-Za-z0-9.\-:%_]+$');

  @override
  void didUpdateWidget(RuleEditor old) {
    super.didUpdateWidget(old);
    if (old.draft.id != widget.draft.id) {
      _d = widget.draft;
      _title.text = _d.title;
      _host.text = _d.target == '*' ? '' : _d.target;
      _error = null;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _host.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final metric = _d.metric;
    final typed = _host.text.trim();
    final target = metric == AlertMetric.newDevice ? '*' : (_d.target == '*' && typed.isEmpty ? '*' : typed);
    String? error;
    if (metric != AlertMetric.newDevice && target.isEmpty) {
      error = 'Pick a target to watch, or choose Any target.';
    } else if (target != '*' && !_hostPattern.hasMatch(target)) {
      error = 'That doesn\'t look like a host name or IP address.';
    } else if (_d.channels == 0) {
      error = 'Pick at least one way to be notified.';
    }
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() => _saving = true);
    await ref.read(alertRulesRepositoryProvider).save(_d.copyWith(title: _title.text, target: target));
    if (mounted) setState(() => _saving = false);
    widget.onDone();
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete "${_title.text.trim().isEmpty ? 'this rule' : _title.text.trim()}"?'),
        content: const Text('The rule stops watching and its alert history is removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true || _d.id == null) return;
    await ref.read(alertRulesRepositoryProvider).delete(_d.id!);
    widget.onDone();
  }

  void _setMetric(String m) => setState(() {
    final wasDefault = _title.text == RuleDraft.defaultTitle(_d.metric);
    _d = _d.copyWith(
      metric: m,
      threshold: m == AlertMetric.loss
          ? 5
          : m == AlertMetric.latency
          ? 100
          : 0,
      forSeconds: m == AlertMetric.down
          ? 10
          : m == AlertMetric.loss
          ? 60
          : 30,
    );
    if (wasDefault || _title.text.isEmpty) _title.text = RuleDraft.defaultTitle(m);
    _error = null;
  });

  Widget _label(String text, {Widget? trailing}) =>
      PulseSectionLabel(text, trailing: trailing, padding: const EdgeInsets.fromLTRB(4, 18, 0, 8));

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final targets = ref.watch(monitorOverviewProvider).value?.rows.map((r) => r.target).toList() ?? const [];
    final (max, unit) = _d.scale;
    final showThreshold = _d.metric == AlertMetric.latency || _d.metric == AlertMetric.loss;
    final showFor = _d.metric != AlertMetric.newDevice;
    final unitLabel = unit.toLowerCase();
    final step = max / 20;

    final fields = <Widget>[
      PulseTargetField(
        controller: _title,
        hint: RuleDraft.defaultTitle(_d.metric),
        icon: PulseIcons.bell,
        keyboardType: TextInputType.text,
      ),
      if (_d.metric != AlertMetric.newDevice) ...[
        _label('Watch'),
        PulseTargetField(
          controller: _host,
          hint: _d.target == '*' ? 'Any monitored target' : 'Host or IP',
          onChanged: (v) => setState(() {
            _d = _d.copyWith(target: v.trim().isEmpty && _d.target == '*' ? '*' : v.trim());
            _error = null;
          }),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          children: [
            PulseChip(
              label: 'Any target',
              small: true,
              selected: _d.target == '*',
              onTap: () => setState(() {
                _d = _d.copyWith(target: '*');
                _host.clear();
                _error = null;
              }),
            ),
            for (final t in targets)
              PulseChip(
                label: t.name.isEmpty ? t.host : '${t.host} · ${t.name}',
                small: true,
                selected: _d.target == t.host,
                onTap: () => setState(() {
                  _d = _d.copyWith(target: t.host);
                  _host.text = t.host;
                  _error = null;
                }),
              ),
          ],
        ),
      ],
      _label('When'),
      PulseButtonGroup<String>(
        segments: [
          for (final m in const [AlertMetric.latency, AlertMetric.loss, AlertMetric.down, AlertMetric.newDevice])
            PulseSegment(m, metricLabel(m)),
        ],
        selected: _d.metric,
        onChanged: _setMetric,
      ),
      if (_d.metric == AlertMetric.newDevice)
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
          child: Text(
            'Fires when an unknown device joins your local network (checked by the background LAN watch).',
            style: context.type.bodySmall!.copyWith(color: c.onSurfaceVariant),
          ),
        ),
      if (showThreshold) ...[
        _label(
          _d.metric == AlertMetric.latency ? 'Latency is above' : 'Loss is above',
          trailing: Padding(
            padding: const EdgeInsets.only(right: 4),
            child: PulseNumber(
              _d.threshold % 1 == 0 ? '${_d.threshold.round()}' : _d.threshold.toStringAsFixed(1),
              unit: unitLabel,
              unitScale: .5,
              style: pulseNumber(28),
            ),
          ),
        ),
        Slider(
          value: _d.threshold.clamp(step, max).toDouble(),
          min: step,
          max: max,
          divisions: 19,
          label: '${_d.threshold.round()} $unitLabel',
          semanticFormatterCallback: (v) => '${v.round()} $unitLabel',
          onChanged: (v) => setState(() => _d = _d.copyWith(threshold: v)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final v in [step, max / 2, max])
                Text(
                  '${v % 1 == 0 ? v.round() : v.toStringAsFixed(1)} $unitLabel',
                  style: context.type.labelMedium!.copyWith(color: c.onSurfaceVariant),
                ),
            ],
          ),
        ),
      ],
      if (showFor) ...[
        _label('For at least'),
        PulseButtonGroup<int>(
          segments: const [
            PulseSegment(10, '10 s'),
            PulseSegment(30, '30 s'),
            PulseSegment(60, '1 min'),
            PulseSegment(300, '5 min'),
          ],
          selected: _d.forSeconds,
          onChanged: (v) => setState(() => _d = _d.copyWith(forSeconds: v)),
        ),
      ],
      _label('Notify via'),
      Wrap(
        spacing: 8,
        children: [
          for (final (bit, label, icon) in [
            (AlertChannel.push, 'Push', PulseIcons.bell),
            if (!Platform.isIOS)
              (AlertChannel.tray, trayChannelLabel, Platform.isAndroid ? PulseIcons.phone : PulseIcons.laptop),
            (AlertChannel.sound, 'Sound', PulseIcons.signal),
          ])
            PulseChip(
              label: label,
              icon: icon,
              selected: _d.channels & bit != 0,
              onTap: () => setState(() {
                _d = _d.copyWith(channels: _d.channels ^ bit);
                _error = null;
              }),
            ),
        ],
      ),
      if (_error != null) ...[const SizedBox(height: 12), PulseErrorBanner(title: 'Can\'t save yet', message: _error)],
    ];

    final buttons = Row(
      children: [
        if (_d.id != null)
          PulseButton(label: 'Delete', icon: PulseIcons.trash, style: PulseButtonStyle.outlined, onPressed: _delete)
        else
          PulseButton(label: 'Cancel', style: PulseButtonStyle.text, onPressed: widget.onDone),
        const Spacer(),
        PulseButton(label: 'Save rule', icon: PulseIcons.check, onPressed: _saving ? null : _save),
      ],
    );

    final pad = widget.compact ? context.pagePadding : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(pad, 4, pad, 16),
            children: [for (var i = 0; i < fields.length; i++) PulseEntrance(index: i ~/ 2, child: fields[i])],
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(pad, 8, pad, widget.compact ? 16 + MediaQuery.paddingOf(context).bottom : 0),
          child: buttons,
        ),
      ],
    );
  }
}
