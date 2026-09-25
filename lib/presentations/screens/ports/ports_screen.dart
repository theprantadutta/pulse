import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/widgets/wire/wire.dart';
import '../../../core/widgets/wire/wire_page.dart';
import '../../../providers/port_scan_provider.dart';
import '../../../services/net/port_scanner.dart';
import '../tools/tool_widgets.dart';

/// 09 — Port scan.
class PortsScreen extends ConsumerStatefulWidget {
  const PortsScreen({super.key, this.initialTarget});
  final String? initialTarget;

  @override
  ConsumerState<PortsScreen> createState() => _PortsScreenState();
}

class _PortsScreenState extends ConsumerState<PortsScreen> {
  late final _target = TextEditingController(text: widget.initialTarget ?? ref.read(portScanProvider).target);

  @override
  void initState() {
    super.initState();
    if (widget.initialTarget != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scan());
    }
  }

  @override
  void dispose() {
    _target.dispose();
    super.dispose();
  }

  void _scan() => ref.read(portScanProvider.notifier).scan(_target.text);

  Future<void> _custom() async {
    final n = ref.read(portScanProvider.notifier);
    final c = TextEditingController(text: ref.read(portScanProvider).customSpec);
    final spec = await showDialog<String>(
      context: context,
      builder: (context) {
        final w = context.wire;
        return Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  color: w.ink,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  child: Text('CUSTOM PORTS', style: WireType.title(26).copyWith(color: w.background)),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                  child: WireInput(
                    controller: c,
                    hint: '22,80,443,8000-8100',
                    autofocus: true,
                    onSubmitted: (v) => Navigator.of(context).pop(v),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
                  child: Text(
                    'Comma-separated ports and ranges, 1–65535.',
                    style: WireType.body(12).copyWith(color: w.text2),
                  ),
                ),
                PanelActions(
                  actions: [
                    (label: 'Cancel', primary: false, onTap: () => Navigator.of(context).pop()),
                    (label: 'Use', primary: true, onTap: () => Navigator.of(context).pop(c.text)),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    if (spec == null) return;
    try {
      parsePortSpec(spec);
      n.setCustom(spec);
    } on FormatException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(portScanProvider);
    final n = ref.read(portScanProvider.notifier);
    final w = context.wire;
    final seconds = s.elapsed == null ? '—' : '${(s.elapsed!.inMilliseconds / 1000).toStringAsFixed(1)}S';
    return WireAdaptive(
      mobile: (context) => WireMobilePage(
        header: WireMobileHeader(
          title: 'Port scan',
          onBack: mobileBack(context),
          trailing: Text(
            s.running
                ? '${s.scanned}/${s.ports.length}'
                : s.results.isEmpty
                ? ''
                : 'DONE',
            style: WireType.label(12).copyWith(color: w.signal),
          ),
        ),
        body: ListView(
          padding: EdgeInsets.zero,
          children: [
            MobileTargetRow(controller: _target, onSubmitted: (_) => _scan(), enabled: !s.running),
            Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: w.ink, width: kWireBorder),
                ),
              ),
              child: WireSegmented<PortPreset>(
                bordered: false,
                height: WireLayout.minHit,
                options: const [
                  (PortPreset.common, 'COMMON'),
                  (PortPreset.wellKnown, '1–1024'),
                  (PortPreset.custom, 'CUSTOM'),
                ],
                selected: s.preset,
                enabled: !s.running,
                onChanged: (p) => p == PortPreset.custom ? _custom() : n.setPreset(p),
              ),
            ),
            if (s.error != null) WireErrorBlock(reason: s.error!, size: 56),
            Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: w.ink, width: kWireBorder),
                ),
              ),
              child: WireSplitRow(
                children: [
                  WireStat(
                    label: 'Open',
                    value: '${s.open.length}',
                    valueSize: 40,
                    tone: WireTone.signal,
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                  ),
                  WireStat(
                    label: 'Filter',
                    value: '${s.filtered.length}',
                    valueSize: 40,
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                  ),
                  WireStat(
                    label: 'Time',
                    value: seconds,
                    valueSize: 40,
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                  ),
                ],
              ),
            ),
            if (s.ports.isNotEmpty)
              Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: w.ink, width: kWireBorder),
                  ),
                ),
                child: _PortMap(state: s, gap: 1),
              ),
            for (final r in [...s.open, ...s.filtered.take(20)])
              WireRow(
                highlight: r.state == PortState.open ? WireRowHighlight.none : WireRowHighlight.muted,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                child: Row(
                  children: [
                    SizedBox(width: 62, child: Text('${r.port}', style: WireType.display(24, width: 65, height: 1))),
                    Expanded(child: Text(r.service.toUpperCase(), style: WireType.data(13))),
                    Text(r.state.name.toUpperCase(), style: WireType.label()),
                  ],
                ),
              ),
          ],
        ),
        action: s.running
            ? WireButton.bar(label: 'Stop', glyph: '■', variant: WireButtonVariant.inverse, onPressed: n.stop)
            : WireButton.bar(label: 'Scan', glyph: '▶', onPressed: _scan),
      ),
      desktop: (context) => WireDesktopPage(
        topBar: ToolTargetBar(
          controller: _target,
          running: s.running,
          subtitle: s.address != null && s.address != s.target ? s.address : null,
          runLabel: 'Scan',
          onRun: _scan,
          onStop: n.stop,
          chips: [
            for (final (p, label) in const [
              (PortPreset.common, 'COMMON'),
              (PortPreset.wellKnown, '1–1024'),
              (PortPreset.custom, 'CUSTOM'),
            ])
              WireTopChip(
                label: p == PortPreset.custom && s.preset == p ? s.customSpec : label,
                selected: s.preset == p,
                onTap: s.running ? null : () => p == PortPreset.custom ? _custom() : n.setPreset(p),
              ),
          ],
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: w.ink, width: kWireBorder),
                ),
              ),
              child: WireSplitRow(
                children: [
                  WireStat(
                    label: 'Scanned',
                    value: '${s.scanned}',
                    valueSize: 64,
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
                  ),
                  WireStat(
                    label: 'Open',
                    value: '${s.open.length}',
                    valueSize: 64,
                    tone: WireTone.signal,
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
                  ),
                  WireStat(
                    label: 'Filtered',
                    value: '${s.filtered.length}',
                    valueSize: 64,
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
                  ),
                  WireStat(
                    label: 'Time',
                    value: seconds,
                    valueSize: 64,
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
                  ),
                ],
              ),
            ),
            if (s.error != null) WireErrorBlock(reason: s.error!, size: 64),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(child: Text('PORT MAP · ${s.rangeLabel}', style: WireType.label())),
                              Text('■ OPEN  ', style: WireType.label().copyWith(color: w.signal)),
                              Text('■ FILTERED  ', style: WireType.label().copyWith(color: w.filtered)),
                              Text('□ CLOSED', style: WireType.label()),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (s.ports.isEmpty)
                            Text('Pick a preset and press SCAN.', style: WireType.body(13).copyWith(color: w.text3))
                          else
                            _PortMap(state: s),
                          const SizedBox(height: 12),
                          if (s.ports.isNotEmpty)
                            Text(
                              'Each cell = ${_perCell(s.ports.length)} port${_perCell(s.ports.length) == 1 ? '' : 's'}. '
                              '${s.running ? 'Scanning' : 'Scanned'} ${s.scanned} of ${s.ports.length} with ${s.concurrency} connections.',
                              style: WireType.body(12).copyWith(color: w.text2),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const WireVRule(),
                  Expanded(child: _OpenTable(state: s)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

int _perCell(int n) => math.max(1, (n / 256).ceil());

/// 32-column grid; open = signal, filtered = filtered colour,
/// closed = empty cell with a 1px border, unscanned = muted.
class _PortMap extends StatelessWidget {
  const _PortMap({required this.state, this.gap = 2});
  final PortScanState state;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final w = context.wire;
    final ports = state.ports;
    final per = _perCell(ports.length);
    final cells = (ports.length / per).ceil();
    final colors = <Color?>[];
    for (var c = 0; c < cells; c++) {
      var open = false, filtered = false, pending = false;
      for (var i = c * per; i < math.min(ports.length, (c + 1) * per); i++) {
        final r = state.results[ports[i]];
        if (r == null) {
          pending = true;
        } else if (r.state == PortState.open) {
          open = true;
        } else if (r.state == PortState.filtered) {
          filtered = true;
        }
      }
      colors.add(
        open
            ? w.signal
            : filtered
            ? w.filtered
            : pending
            ? w.mutedRow
            : null,
      );
    }
    return LayoutBuilder(
      builder: (context, box) {
        final size = (box.maxWidth - gap * 31) / 32;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final c in colors)
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: c,
                  border: Border.all(color: w.ink, width: 1),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _OpenTable extends StatelessWidget {
  const _OpenTable({required this.state});
  final PortScanState state;

  static const cols = [WireCol('Port', width: 70), WireCol('Service', flex: 1), WireCol('State', width: 80)];

  @override
  Widget build(BuildContext context) {
    final w = context.wire;
    final open = state.open;
    final filtered = state.filtered;
    final shownFiltered = filtered.take(50).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const WireTableHeader(columns: cols, gap: 10),
        Expanded(
          child: ListView(
            children: [
              if (open.isEmpty && !state.running && state.results.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text('No open ports in this range.', style: WireType.body(13).copyWith(color: w.text2)),
                ),
              for (final r in [...open, ...shownFiltered])
                WireRow(
                  highlight: r.state == PortState.open ? WireRowHighlight.none : WireRowHighlight.muted,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: WireColumns(
                    columns: cols,
                    gap: 10,
                    cells: [
                      Text('${r.port}', style: WireType.display(28, width: 65, height: 1)),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r.service.toUpperCase(), style: WireType.data(14)),
                          Text(
                            r.state == PortState.open ? (r.banner ?? 'no banner') : 'no response',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: WireType.body(12).copyWith(color: w.text2, height: 1.3),
                          ),
                        ],
                      ),
                      Text(r.state.name.toUpperCase(), style: WireType.label(12)),
                    ],
                  ),
                ),
              if (filtered.length > shownFiltered.length)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    '+ ${filtered.length - shownFiltered.length} more filtered',
                    style: WireType.body(12).copyWith(color: w.text3),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
