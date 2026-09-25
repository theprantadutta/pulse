import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/format.dart';
import '../../../core/widgets/wire/wire.dart';
import '../../../core/widgets/wire/wire_page.dart';
import '../../../data/db/app_database.dart';
import '../../../providers/monitor_provider.dart';
import '../../navigation/destinations.dart';
import '../tools/tool_widgets.dart';

/// 12 — Monitor.
class MonitorScreen extends ConsumerWidget {
  const MonitorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final w = context.wire;
    final run = ref.watch(monitorRunnerProvider);
    final range = ref.watch(monitorRangeProvider);
    final overview = ref.watch(monitorOverviewProvider).value;
    final incidents = ref.watch(incidentsProvider).value ?? const [];
    final rows = overview?.rows ?? const <TargetRow>[];
    final runner = ref.read(monitorRunnerProvider.notifier);

    Widget empty() => WireEmptyState(
      title: 'Nothing watched',
      message: 'Add a host and Pulse checks it every ${_every(ref)} — even with the window closed.',
      actionLabel: 'Add target',
      actionGlyph: '+',
      onAction: () => showAddTargetDialog(context, ref),
      compact: context.isMobileLayout,
    );

    return WireAdaptive(
      mobile: (context) => WireMobilePage(
        header: WireMobileHeader(
          title: 'Monitor',
          onBack: mobileBack(context),
          trailing: WirePressable(
            onTap: () => showAddTargetDialog(context, ref),
            tone: WireTone.ink,
            semanticLabel: 'Add target',
            builder: (context, c, s) => Container(
              color: c.bg,
              height: WireLayout.mobileHeader,
              alignment: Alignment.center,
              child: Text('+ ADD', style: WireType.label(12).copyWith(color: s.isEmpty ? w.signal : c.fg)),
            ),
          ),
        ),
        body: rows.isEmpty
            ? empty()
            : ListView(
                padding: EdgeInsets.zero,
                children: [
                  WireSplitRow(
                    children: [
                      WireStat(
                        label: 'Uptime ${range.label}',
                        value: fmtPct(overview?.uptime),
                        valueSize: 46,
                        tone: WireTone.signal,
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                      ),
                      WireStat(
                        label: 'Incidents',
                        value: '${overview?.incidents ?? 0}',
                        valueSize: 46,
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                      ),
                    ],
                  ),
                  const WireRule(),
                  _StatusLine(run: run, onToggle: runner.togglePaused),
                  for (final r in rows) _MobileTargetRow(row: r),
                ],
              ),
        action: WireButton.bar(
          label: 'Alerts →',
          variant: WireButtonVariant.inverse,
          onPressed: () => context.push(Routes.alerts),
        ),
      ),
      desktop: (context) => WireDesktopPage(
        panelWidth: 320,
        topBar: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: WireTopTitle(
                'Monitor',
                subtitle: '● ${run.label} · ${rows.length} TARGET${rows.length == 1 ? '' : 'S'}',
              ),
            ),
            const WireVRule(),
            WireTopChip(
              label: run.mode == MonitorMode.paused ? '▶ RESUME' : '■ PAUSE',
              onTap: rows.isEmpty ? null : runner.togglePaused,
            ),
            for (final r in MonitorRange.values)
              WireTopChip(
                label: r.label,
                selected: r == range,
                onTap: () => ref.read(monitorRangeProvider.notifier).set(r),
              ),
            WireButton(
              label: 'Add target',
              glyph: '+',
              variant: WireButtonVariant.primary,
              bordered: false,
              fontSize: 17,
              height: WireLayout.topBar,
              padding: const EdgeInsets.symmetric(horizontal: 28),
              onPressed: () => showAddTargetDialog(context, ref),
            ),
          ],
        ),
        body: rows.isEmpty
            ? empty()
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: w.ink, width: kWireBorder))),
                    child: WireSplitRow(
                      children: [
                        WireStat(
                          label: 'Uptime ${range.label}',
                          value: fmtPct(overview?.uptime),
                          valueSize: 64,
                          tone: WireTone.signal,
                          padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
                        ),
                        WireStat(
                          label: 'Avg latency',
                          value: overview?.avgMs == null ? '—' : '${fmtMs(overview!.avgMs)} MS',
                          valueSize: 64,
                          padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
                        ),
                        WireStat(label: 'Incidents', value: '${overview?.incidents ?? 0}', valueSize: 64, padding: const EdgeInsets.fromLTRB(20, 14, 20, 14)),
                        WireStat(label: 'Checks', value: fmtCount(overview?.checks ?? 0), valueSize: 64, padding: const EdgeInsets.fromLTRB(20, 14, 20, 14)),
                      ],
                    ),
                  ),
                  WireTableHeader(
                    columns: _cols,
                    gap: 14,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  ),
                  Expanded(
                    child: ListView(
                      children: [
                        for (final r in rows) _DesktopTargetRow(row: r),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                          child: Row(
                            children: [
                              Text('■ HEALTHY   ', style: WireType.label()),
                              Text('■ DEGRADED   ', style: WireType.label().copyWith(color: w.degraded)),
                              Text('■ DOWN   ', style: WireType.label().copyWith(color: w.signal)),
                              Text('■ NO DATA', style: WireType.label().copyWith(color: w.text3)),
                              const Spacer(),
                              Text(
                                run.last == null ? '' : 'LAST CHECK ${fmtWhen(run.last!.at)}',
                                style: WireType.label().copyWith(color: w.text2),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
        panel: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const WireSectionBar('Incidents'),
            Expanded(
              child: incidents.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text('No incidents. Outages, loss and latency spikes show up here.', style: WireType.body(13).copyWith(color: w.text3)),
                    )
                  : ListView(children: [for (final i in incidents) _IncidentRow(view: i)]),
            ),
          ],
        ),
      ),
    );
  }

  static const _cols = [
    WireCol('Target', width: 170),
    WireCol('Last · blocks', flex: 1),
    WireCol('Uptime', width: 70),
    WireCol('Now', width: 80, align: TextAlign.right),
  ];
}

String _every(WidgetRef ref) {
  final s = ref.read(monitorRunnerProvider);
  return s.mode == MonitorMode.service ? 'minute in the background' : 'minute';
}

List<Color> _blockColors(BuildContext context, List<BlockState> blocks) {
  final w = context.wire;
  return [
    for (final b in blocks)
      switch (b) {
        BlockState.healthy => w.ink,
        BlockState.degraded => w.degraded,
        BlockState.down => w.signal,
        BlockState.empty => w.mutedRow,
      },
  ];
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.run, required this.onToggle});
  final MonitorRunState run;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return WireRow(
      onTap: onToggle,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      divider: kWireBorder,
      child: Row(
        children: [
          Expanded(child: Text('● ${run.label}', style: WireType.label())),
          Text(run.mode == MonitorMode.paused ? 'RESUME' : 'PAUSE', style: WireType.label()),
        ],
      ),
    );
  }
}

class _DesktopTargetRow extends ConsumerWidget {
  const _DesktopTargetRow({required this.row});
  final TargetRow row;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final w = context.wire;
    final r = row;
    return WireRow(
      highlight: r.incident ? WireRowHighlight.tint : r.target.enabled ? WireRowHighlight.none : WireRowHighlight.muted,
      onTap: () => showTargetMenu(context, ref, r.target),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: WireColumns(
        columns: MonitorScreen._cols,
        gap: 14,
        cells: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(r.target.host, maxLines: 1, overflow: TextOverflow.ellipsis, style: WireType.data(14)),
              Text(
                r.target.enabled ? (r.target.name.isEmpty ? '—' : r.target.name) : 'PAUSED',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: WireType.body(11).copyWith(color: w.text2, height: 1.3),
              ),
            ],
          ),
          WireStatusStrip(colors: _blockColors(context, r.blocks), height: 26),
          Text(fmtPct(r.uptime), style: WireType.data(13)),
          Text(r.nowDown ? 'DOWN' : fmtMs(r.nowMs), style: WireType.stat(26).copyWith(color: r.nowDown ? w.signal : w.ink)),
        ],
      ),
    );
  }
}

class _MobileTargetRow extends ConsumerWidget {
  const _MobileTargetRow({required this.row});
  final TargetRow row;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final w = context.wire;
    final r = row;
    return WireRow(
      highlight: r.incident ? WireRowHighlight.tint : WireRowHighlight.none,
      onTap: () => showTargetMenu(context, ref, r.target),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.target.host, style: WireType.data(13)),
                    Text(
                      '${r.target.name.isEmpty ? '—' : r.target.name} · ${fmtPct(r.uptime)}',
                      style: WireType.body(11).copyWith(color: w.text2, height: 1.3),
                    ),
                  ],
                ),
              ),
              Text(r.nowDown ? 'DOWN' : fmtMs(r.nowMs), style: WireType.stat(24).copyWith(color: r.nowDown ? w.signal : w.ink)),
            ],
          ),
          const SizedBox(height: 8),
          WireStatusStrip(colors: _blockColors(context, r.blocks), height: 14, gap: 1),
        ],
      ),
    );
  }
}

class _IncidentRow extends StatelessWidget {
  const _IncidentRow({required this.view});
  final IncidentView view;

  @override
  Widget build(BuildContext context) {
    final w = context.wire;
    final i = view.incident;
    final dur = view.ongoing ? 'ONGOING' : fmtDuration(i.endedAt!.difference(i.startedAt));
    return WireRow(
      highlight: view.ongoing ? WireRowHighlight.tint : WireRowHighlight.none,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(fmtWhen(i.startedAt), style: WireType.label())),
              Text(dur, style: WireType.label()),
            ],
          ),
          const SizedBox(height: 3),
          Text(i.title.toUpperCase(), style: WireType.title(20)),
          Text(i.description, style: WireType.body(12).copyWith(color: w.text2, height: 1.3)),
        ],
      ),
    );
  }
}

/// Add a monitored host.
Future<void> showAddTargetDialog(BuildContext context, WidgetRef ref, {String host = '', String name = ''}) {
  final hostC = TextEditingController(text: host);
  final nameC = TextEditingController(text: name);
  return showDialog<void>(
    context: context,
    builder: (context) {
      final w = context.wire;
      Future<void> save() async {
        final h = hostC.text.trim();
        if (h.isEmpty || !RegExp(r'^[A-Za-z0-9.\-:%_]+$').hasMatch(h)) return;
        await ref.read(monitorTargetsRepositoryProvider).add(h, nameC.text.trim());
        if (context.mounted) Navigator.of(context).pop();
      }

      return Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                color: w.ink,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Text('ADD TARGET', style: WireType.title(26).copyWith(color: w.background)),
              ),
              Padding(padding: const EdgeInsets.fromLTRB(20, 18, 20, 6), child: Text('HOST OR IP', style: WireType.label())),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: WireInput(controller: hostC, hint: '8.8.8.8', autofocus: true, keyboardType: TextInputType.url, onSubmitted: (_) => save()),
              ),
              Padding(padding: const EdgeInsets.fromLTRB(20, 14, 20, 6), child: Text('NAME', style: WireType.label())),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: WireInput(controller: nameC, hint: 'Google DNS', onSubmitted: (_) => save()),
              ),
              const SizedBox(height: 20),
              PanelActions(
                actions: [
                  (label: 'Cancel', primary: false, onTap: () => Navigator.of(context).pop()),
                  (label: 'Add', primary: true, onTap: save),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Pause / rename / remove a target.
Future<void> showTargetMenu(BuildContext context, WidgetRef ref, MonitorTarget t) {
  final repo = ref.read(monitorTargetsRepositoryProvider);
  final nameC = TextEditingController(text: t.name);
  return showDialog<void>(
    context: context,
    builder: (context) {
      final w = context.wire;
      return Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                color: w.ink,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Text(t.host.toUpperCase(), style: WireType.title(26).copyWith(color: w.background)),
              ),
              Padding(padding: const EdgeInsets.fromLTRB(20, 18, 20, 6), child: Text('NAME', style: WireType.label())),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: WireInput(controller: nameC, hint: 'Name'),
              ),
              const SizedBox(height: 20),
              PanelActions(
                actions: [
                  (
                    label: 'Remove',
                    primary: false,
                    onTap: () async {
                      await repo.delete(t.id);
                      if (context.mounted) Navigator.of(context).pop();
                    },
                  ),
                  (
                    label: t.enabled ? 'Pause' : 'Resume',
                    primary: false,
                    onTap: () async {
                      await repo.update(t.id, enabled: !t.enabled);
                      if (context.mounted) Navigator.of(context).pop();
                    },
                  ),
                  (
                    label: 'Save',
                    primary: true,
                    onTap: () async {
                      await repo.update(t.id, name: nameC.text.trim());
                      if (context.mounted) Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}
