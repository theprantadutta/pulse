import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/widgets/wire/wire.dart';
import '../../../providers/alerts_provider.dart';
import '../../../providers/monitor_provider.dart';
import '../../../services/background/monitor_engine.dart';

/// Rule editor: WATCH, WHEN, IS ABOVE, FOR AT LEAST, NOTIFY VIA.
class RuleEditor extends ConsumerStatefulWidget {
  const RuleEditor({super.key, required this.draft, required this.onDone, this.compact = false});
  final RuleDraft draft;
  final VoidCallback onDone;
  final bool compact;

  @override
  ConsumerState<RuleEditor> createState() => _RuleEditorState();
}

class _RuleEditorState extends ConsumerState<RuleEditor> {
  late RuleDraft _d = widget.draft;
  late final _title = TextEditingController(text: widget.draft.title);
  late final _host = TextEditingController(text: widget.draft.target == '*' ? '' : widget.draft.target);
  String? _error;

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
    final target = metric == AlertMetric.newDevice ? '*' : (_d.target == '*' ? '*' : _host.text.trim());
    if (metric != AlertMetric.newDevice && target.isEmpty) {
      setState(() => _error = 'Pick a target to watch.');
      return;
    }
    await ref.read(alertRulesRepositoryProvider).save(_d.copyWith(title: _title.text, target: target));
    widget.onDone();
  }

  Widget _section(String label, Widget child, {Widget? trailing}) {
    final w = context.wire;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: widget.compact ? 14 : 20, vertical: 14),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: w.ink, width: kWireBorder))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: Text(label, style: WireType.label())),
              ?trailing,
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final w = context.wire;
    final targets = ref.watch(monitorOverviewProvider).value?.rows.map((r) => r.target).toList() ?? const [];
    final (max, unit) = _d.scale;
    final showThreshold = _d.metric == AlertMetric.latency || _d.metric == AlertMetric.loss;
    final showFor = _d.metric != AlertMetric.newDevice;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          color: w.signalTint,
          padding: EdgeInsets.fromLTRB(widget.compact ? 14 : 20, 14, widget.compact ? 14 : 20, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_d.id == null ? 'NEW RULE' : 'EDIT RULE', style: WireType.label()),
              TextField(
                controller: _title,
                cursorColor: w.signal,
                cursorWidth: 10,
                cursorRadius: Radius.zero,
                style: WireType.title(32).copyWith(color: w.ink),
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.zero,
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  isCollapsed: true,
                ),
              ),
            ],
          ),
        ),
        const WireRule(),
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              if (_d.metric != AlertMetric.newDevice)
                _section(
                  'WATCH',
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      WireInput(
                        controller: _host,
                        hint: _d.target == '*' ? 'Any monitored target' : 'host or IP',
                        onChanged: (v) => setState(() => _d = _d.copyWith(target: v.trim())),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _Chip(
                            label: 'ANY TARGET',
                            on: _d.target == '*',
                            onTap: () => setState(() {
                              _d = _d.copyWith(target: '*');
                              _host.clear();
                            }),
                          ),
                          for (final t in targets)
                            _Chip(
                              label: t.name.isEmpty ? t.host : '${t.host} · ${t.name}',
                              on: _d.target == t.host,
                              onTap: () => setState(() {
                                _d = _d.copyWith(target: t.host);
                                _host.text = t.host;
                              }),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              _section(
                'WHEN',
                WireSegmented<String>(
                  height: 40,
                  options: const [
                    (AlertMetric.latency, 'LATENCY'),
                    (AlertMetric.loss, 'LOSS'),
                    (AlertMetric.down, 'DOWN'),
                    (AlertMetric.newDevice, 'NEW DEVICE'),
                  ],
                  selected: _d.metric,
                  onChanged: (m) => setState(() {
                    final wasDefault = _title.text == RuleDraft.defaultTitle(_d.metric);
                    _d = _d.copyWith(
                      metric: m,
                      threshold: m == AlertMetric.loss ? 5 : m == AlertMetric.latency ? 100 : 0,
                      forSeconds: m == AlertMetric.down ? 10 : m == AlertMetric.loss ? 60 : 30,
                    );
                    if (wasDefault || _title.text.isEmpty) _title.text = RuleDraft.defaultTitle(m);
                  }),
                ),
              ),
              if (showThreshold)
                _section(
                  'IS ABOVE',
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _BlockSlider(
                        value: _d.threshold,
                        max: max,
                        onChanged: (v) => setState(() => _d = _d.copyWith(threshold: v)),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('0', style: WireType.body(11).copyWith(color: w.text2, height: 1)),
                          Text('${(max / 2).round()}', style: WireType.body(11).copyWith(color: w.text2, height: 1)),
                          Text('${max.round()} $unit', style: WireType.body(11).copyWith(color: w.text2, height: 1)),
                        ],
                      ),
                    ],
                  ),
                  trailing: Text('${_d.threshold.round()} $unit', style: WireType.display(40, width: 65, height: 1)),
                ),
              if (showFor)
                _section(
                  'FOR AT LEAST',
                  WireSegmented<int>(
                    height: 40,
                    options: const [(10, '10S'), (30, '30S'), (60, '1M'), (300, '5M')],
                    selected: _d.forSeconds,
                    onChanged: (v) => setState(() => _d = _d.copyWith(forSeconds: v)),
                  ),
                ),
              _section(
                'NOTIFY VIA',
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final (bit, label) in const [
                      (AlertChannel.push, 'PUSH'),
                      (AlertChannel.tray, 'TRAY'),
                      (AlertChannel.sound, 'SOUND'),
                    ])
                      _Chip(
                        label: '${_d.channels & bit != 0 ? '✓ ' : ''}$label',
                        on: _d.channels & bit != 0,
                        bordered: true,
                        onTap: () => setState(() => _d = _d.copyWith(channels: _d.channels ^ bit)),
                      ),
                  ],
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(_error!, style: WireType.body(12).copyWith(color: w.signal)),
                ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(border: Border(top: BorderSide(color: w.ink, width: kWireBorder))),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: WireButton(
                    label: _d.id == null ? 'Cancel' : 'Delete',
                    bordered: false,
                    sides: WireSides.onlyRight,
                    fontSize: 16,
                    height: 52,
                    onPressed: () async {
                      if (_d.id != null) await ref.read(alertRulesRepositoryProvider).delete(_d.id!);
                      widget.onDone();
                    },
                  ),
                ),
                Expanded(
                  child: WireButton(
                    label: 'Save rule',
                    variant: WireButtonVariant.primary,
                    bordered: false,
                    fontSize: 16,
                    height: 52,
                    onPressed: _save,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.on, required this.onTap, this.bordered = true});
  final String label;
  final bool on;
  final VoidCallback onTap;
  final bool bordered;

  @override
  Widget build(BuildContext context) {
    final w = context.wire;
    return WirePressable(
      onTap: onTap,
      selected: on,
      semanticLabel: label,
      builder: (context, c, s) => Container(
        constraints: const BoxConstraints(minHeight: 36),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: c.bg, border: Border.all(color: w.ink, width: kWireBorder)),
        child: Text(label, style: WireType.label(12).copyWith(color: c.fg)),
      ),
    );
  }
}

/// 20-segment block slider; tap or drag to set.
class _BlockSlider extends StatelessWidget {
  const _BlockSlider({required this.value, required this.max, required this.onChanged});
  final double value;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final w = context.wire;
    const n = 20;
    final filled = (value / max * n).round().clamp(0, n);
    return LayoutBuilder(
      builder: (context, box) {
        void set(double dx) {
          final seg = (dx / box.maxWidth * n).ceil().clamp(1, n);
          onChanged(seg / n * max);
        }

        return MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => set(d.localPosition.dx),
            onHorizontalDragUpdate: (d) => set(d.localPosition.dx),
            child: Semantics(
              slider: true,
              value: '${value.round()}',
              child: SizedBox(
                height: 32,
                child: Center(
                  child: WireStatusStrip(
                    colors: [for (var i = 0; i < n; i++) i < filled ? w.ink : Colors.transparent],
                    gap: 3,
                    height: 22,
                    borderColor: w.ink,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
