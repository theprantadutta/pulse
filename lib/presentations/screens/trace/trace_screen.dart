import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/format.dart';
import '../../../core/widgets/wire/wire.dart';
import '../../../core/widgets/wire/wire_page.dart';
import '../../../data/models/app_settings.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/trace_provider.dart';
import '../../../services/export_service.dart';
import '../../../services/net/traceroute.dart';
import '../tools/tool_widgets.dart';

/// 08 — Traceroute.
class TraceScreen extends ConsumerStatefulWidget {
  const TraceScreen({super.key, this.initialTarget});
  final String? initialTarget;

  @override
  ConsumerState<TraceScreen> createState() => _TraceScreenState();
}

class _TraceScreenState extends ConsumerState<TraceScreen> {
  late final _target = TextEditingController(text: widget.initialTarget ?? ref.read(traceProvider).target);

  @override
  void initState() {
    super.initState();
    if (widget.initialTarget != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _run());
    }
  }

  @override
  void dispose() {
    _target.dispose();
    super.dispose();
  }

  void _run() => ref.read(traceProvider.notifier).run(_target.text);

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(traceProvider);
    final n = ref.read(traceProvider.notifier);
    final w = context.wire;
    return WireAdaptive(
      mobile: (context) => WireMobilePage(
        header: WireMobileHeader(
          title: 'Traceroute',
          onBack: mobileBack(context),
          trailing: Text(
            s.hops.isEmpty ? '' : '${s.hops.length} HOPS',
            style: WireType.label(12).copyWith(color: w.signal),
          ),
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MobileTargetRow(controller: _target, onSubmitted: (_) => _run(), enabled: !s.running),
            if (s.error != null) WireErrorBlock(reason: s.error!, size: 56),
            Expanded(child: _HopList(state: s, mobile: true)),
            if (s.hops.isNotEmpty)
              Container(
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: w.ink, width: kWireBorder),
                  ),
                ),
                child: WireSplitRow(
                  children: [
                    WireStat(
                      label: 'Total',
                      value: s.totalRtt == null ? '—' : '${fmtMs(s.totalRtt)} MS',
                      valueSize: 30,
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                    ),
                    WireStat(
                      label: 'Route',
                      value: s.route.isEmpty ? '—' : '${s.route.first.cc} → ${s.route.last.cc}',
                      valueSize: 30,
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                    ),
                  ],
                ),
              ),
          ],
        ),
        action: s.running
            ? WireButton.bar(label: 'Stop', glyph: '■', variant: WireButtonVariant.inverse, onPressed: n.stop)
            : WireButton.bar(
                label: s.hops.isEmpty ? 'Trace' : 'Run again',
                glyph: s.hops.isEmpty ? '▶' : '↻',
                onPressed: _run,
              ),
      ),
      desktop: (context) => WireDesktopPage(
        panelWidth: 340,
        topBar: ToolTargetBar(
          controller: _target,
          running: s.running,
          subtitle: s.destination != null && s.destination != s.target ? s.destination : null,
          runLabel: s.hops.isEmpty ? 'Trace' : 'Run again',
          runGlyph: s.hops.isEmpty ? '▶' : '↻',
          runVariant: s.hops.isEmpty ? WireButtonVariant.primary : WireButtonVariant.inverse,
          onRun: _run,
          onStop: n.stop,
          chips: [
            CycleChip<int>(
              values: const [15, 30, 64],
              value: s.maxHops,
              label: (v) => 'MAX $v HOPS',
              enabled: !s.running,
              onChanged: n.setMaxHops,
            ),
            CycleChip<int>(
              values: const [1, 3, 5],
              value: s.probes,
              label: (v) => '$v PROBE${v == 1 ? '' : 'S'}',
              enabled: !s.running,
              onChanged: n.setProbes,
            ),
          ],
        ),
        body: s.error != null
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [WireErrorBlock(reason: s.error!, onRetry: _run)],
              )
            : s.hops.isEmpty && !s.running
            ? const WireEmptyState(title: 'No route yet', message: 'Enter a host and trace the path your packets take.')
            : _HopList(state: s),
        panel: _Summary(state: s),
      ),
    );
  }
}

class _HopList extends StatelessWidget {
  const _HopList({required this.state, this.mobile = false});
  final TraceState state;
  final bool mobile;

  static const cols = [
    WireCol('Hop', width: 44),
    WireCol('Host / IP', flex: 5),
    WireCol('RTT', flex: 3),
    WireCol('Loc', width: 44),
  ];

  @override
  Widget build(BuildContext context) {
    final w = context.wire;
    final hops = state.hops;
    final maxAvg = hops.map((h) => h.avg ?? 0).fold<double>(1, math.max);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!mobile) const WireTableHeader(columns: cols),
        Expanded(
          child: ListView.builder(
            itemCount: hops.length + (state.running ? 1 : 0),
            itemBuilder: (context, i) {
              if (i == hops.length) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      WireBusyGlyph(color: w.ink),
                      const SizedBox(width: 10),
                      Text('Probing hop ${hops.length + 1}…', style: WireType.body(13)),
                    ],
                  ),
                );
              }
              final h = hops[i];
              final last = h.reached;
              final hl = h.timedOut
                  ? WireRowHighlight.muted
                  : last
                  ? WireRowHighlight.tint
                  : WireRowHighlight.none;
              final probes = h.timedOut ? '* * *' : h.probes.map((p) => p == null ? '*' : fmtMs(p)).join(' / ');
              final title = h.timedOut ? 'no reply' : h.host ?? h.ip ?? '*';
              final frac = (h.avg ?? 0) / maxAvg;
              if (mobile) {
                return WireRow(
                  highlight: hl,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      SizedBox(width: 36, child: Text(h.n.toString().padLeft(2, '0'), style: WireType.stat(22))),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: WireType.data(12)),
                            const SizedBox(height: 4),
                            Container(
                              height: 6,
                              color: w.mutedRow,
                              alignment: Alignment.centerLeft,
                              child: FractionallySizedBox(
                                widthFactor: frac.clamp(0, 1),
                                child: Container(color: last ? w.signal : w.ink),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(h.avg == null ? '—' : fmtMs(h.avg), style: WireType.stat(22)),
                    ],
                  ),
                );
              }
              return WireRow(
                highlight: hl,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: WireColumns(
                  columns: cols,
                  cells: [
                    Text(h.n.toString().padLeft(2, '0'), style: WireType.display(30, width: 65, height: 1)),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: WireType.data(14)),
                        Text(
                          [if (h.host != null && h.ip != null) h.ip!, probes].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: WireType.body(12).copyWith(color: w.text2, height: 1.3),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 14,
                            decoration: BoxDecoration(
                              border: Border.all(color: w.ink, width: kWireBorder),
                            ),
                            alignment: Alignment.centerLeft,
                            child: FractionallySizedBox(
                              widthFactor: frac.clamp(0, 1),
                              child: Container(color: last ? w.signal : w.ink),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 48,
                          child: Text(
                            h.avg == null ? '—' : fmtMs(h.avg),
                            textAlign: TextAlign.right,
                            style: WireType.stat(22),
                          ),
                        ),
                      ],
                    ),
                    Text(h.countryCode ?? '', style: WireType.label(12)),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _Summary extends ConsumerWidget {
  const _Summary({required this.state});
  final TraceState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final w = context.wire;
    final s = state;
    final jump = biggestJump(s.hops);
    final title = s.running
        ? 'TRACING…'
        : s.reached
        ? 'DESTINATION REACHED'
        : s.hops.isEmpty
        ? 'READY'
        : 'NOT REACHED';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          color: s.reached && !s.running
              ? w.signal
              : s.hops.isNotEmpty && !s.running
              ? w.signalTint
              : null,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: WireType.label().copyWith(color: s.reached && !s.running ? w.onSignal : w.ink)),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: '${s.hops.length} '),
                    TextSpan(text: 'HOPS', style: WireType.hero(32)),
                  ],
                ),
                style: WireType.hero(96).copyWith(color: s.reached && !s.running ? w.onSignal : w.ink),
              ),
            ],
          ),
        ),
        const WireRule(),
        WireSplitRow(
          children: [
            WireStat(
              label: 'Total RTT',
              value: s.totalRtt == null ? '—' : '${fmtMs(s.totalRtt)} MS',
              valueSize: 32,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            ),
            WireStat(
              label: 'Timeouts',
              value: '${s.timeouts}',
              valueSize: 32,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            ),
          ],
        ),
        const WireRule(),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ROUTE', style: WireType.label()),
              const SizedBox(height: 10),
              _RouteDiagram(route: s.route),
            ],
          ),
        ),
        const WireRule(),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('BIGGEST JUMP', style: WireType.label()),
              const SizedBox(height: 6),
              jump == null
                  ? Text(s.finished ? 'Latency grows evenly along the path.' : '—', style: WireType.body(14))
                  : Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text:
                                'Hop ${jump.from.toString().padLeft(2, '0')} → ${jump.to.toString().padLeft(2, '0')} adds ',
                          ),
                          TextSpan(
                            text: '${fmtMs(jump.addMs)} ms',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          TextSpan(text: ' — ${jump.text}.'),
                        ],
                      ),
                      style: WireType.body(14),
                    ),
            ],
          ),
        ),
        const Spacer(),
        PanelActions(
          actions: [
            (
              label: 'Copy',
              primary: false,
              onTap: s.hops.isEmpty
                  ? null
                  : () async {
                      await Clipboard.setData(ClipboardData(text: s.toText()));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Route copied')));
                      }
                    },
            ),
            (
              label: 'Save',
              primary: false,
              onTap: s.hops.isEmpty
                  ? null
                  : () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final path = await const ExportService().save(
                        fileName: ExportService.stampedName('trace-${s.target}', ExportFormat.txt),
                        content: s.toText(),
                        settings: ref.read(settingsProvider),
                      );
                      if (path != null) messenger.showSnackBar(SnackBar(content: Text('Saved $path')));
                    },
            ),
          ],
        ),
      ],
    );
  }
}

class _RouteDiagram extends StatelessWidget {
  const _RouteDiagram({required this.route});
  final List<({String cc, double? addMs})> route;

  @override
  Widget build(BuildContext context) {
    final w = context.wire;
    if (route.isEmpty) return Text('—', style: WireType.body(14));
    final shown = route.length <= 4 ? route : [route.first, route[route.length ~/ 2], route.last];
    Widget box(String cc, bool last) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: last ? w.ink : null,
        border: Border.all(color: w.ink, width: kWireBorder),
      ),
      child: Text(cc, style: WireType.stat(26).copyWith(color: last ? w.background : w.ink)),
    );
    return Row(
      children: [
        for (var i = 0; i < shown.length; i++) ...[
          if (i > 0) ...[
            Expanded(
              child: Container(height: kWireBorder, color: w.ink),
            ),
            if (shown[i].addMs != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text('+${fmtMs(math.max(0, shown[i].addMs!))} MS', style: WireType.label()),
              ),
            Expanded(
              child: Container(height: kWireBorder, color: w.ink),
            ),
          ],
          box(shown[i].cc, i == shown.length - 1),
        ],
      ],
    );
  }
}
