import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/widgets/pulse/pulse.dart';
import '../../../providers/port_scan_provider.dart';
import '../../../services/net/port_scanner.dart';
import '../../navigation/destinations.dart';
import 'port_map.dart';

/// 07 Port scan. Phone: target, range group (Common · 1–1024 · Custom), three
/// shape stats, the port map and the results list. Tablet: field + group row,
/// four stat cards, a full-width port map and the results.
class PortsScreen extends ConsumerStatefulWidget {
  const PortsScreen({super.key, this.initialTarget});
  final String? initialTarget;

  @override
  ConsumerState<PortsScreen> createState() => _PortsScreenState();
}

const _presetSegments = [
  PulseSegment(PortPreset.common, 'Common'),
  PulseSegment(PortPreset.wellKnown, '1–1024'),
  PulseSegment(PortPreset.custom, 'Custom'),
];

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

  void _scan() {
    FocusScope.of(context).unfocus();
    ref.read(portScanProvider.notifier).scan(_target.text);
  }

  void _toggle() => ref.read(portScanProvider).running ? ref.read(portScanProvider.notifier).stop() : _scan();

  void _pick(PortPreset p) => p == PortPreset.custom ? _custom() : ref.read(portScanProvider.notifier).setPreset(p);

  Future<void> _custom() async {
    final spec = await showModalBottomSheet<String>(
      useRootNavigator: true,
      context: context,
      isScrollControlled: true,
      builder: (context) => _CustomRangeSheet(initial: ref.read(portScanProvider).customSpec),
    );
    if (spec != null) ref.read(portScanProvider.notifier).setCustom(spec);
  }

  /// Ports the current preset would scan (for the idle map preview).
  List<int> _presetPorts(PortScanState s) {
    try {
      return switch (s.preset) {
        PortPreset.common => kCommonPorts,
        PortPreset.wellKnown => [for (var p = 1; p <= 1024; p++) p],
        PortPreset.custom => parsePortSpec(s.customSpec),
      };
    } on FormatException {
      return const [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(portScanProvider);
    final compact = context.isCompact;
    final preview = _presetPorts(s);
    // The last scan belongs to the selected range when its port list matches.
    final current =
        s.ports.isNotEmpty &&
        (s.running ||
            (s.ports.length == preview.length && s.ports.first == preview.first && s.ports.last == preview.last));
    final ports = current ? s.ports : preview;
    final results = current ? s.results : const <int, PortResult>{};
    final open = current ? s.open : const <PortResult>[];
    final filtered = current ? s.filtered : const <PortResult>[];
    final done = current && !s.running && s.results.isNotEmpty;
    final seconds = !current || s.elapsed == null || (s.running && s.scanned == 0)
        ? (s.running ? '0.0' : '—')
        : (s.elapsed!.inMilliseconds / 1000).toStringAsFixed(1);
    final rangeTitle = switch (s.preset) {
      PortPreset.common => 'common',
      PortPreset.wellKnown => '1–1024',
      PortPreset.custom => s.customSpec,
    };
    final showAddress = s.address != null && s.target.isNotEmpty && _target.text.trim() == s.target;

    final field = PulseTargetField(
      controller: _target,
      hint: 'Host or IP to scan',
      enabled: !s.running,
      onSubmitted: (_) => _scan(),
      onChanged: (_) => setState(() {}),
      trailing: showAddress && s.address != s.target ? s.address : null,
    );
    final group = PulseButtonGroup<PortPreset>(
      segments: _presetSegments,
      selected: s.preset,
      small: compact,
      onChanged: s.running ? null : _pick,
    );
    final customNote = s.preset == PortPreset.custom
        ? Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
            child: Text(
              'Custom: ${s.customSpec} · ${preview.length} port${preview.length == 1 ? '' : 's'}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.type.bodySmall!.copyWith(color: context.colors.onSurfaceVariant),
            ),
          )
        : null;
    final progress = s.running
        ? Padding(
            padding: const EdgeInsets.only(top: 12),
            child: PulseWavyBar(
              value: s.ports.isEmpty ? 0 : s.scanned / s.ports.length,
              semanticLabel: 'Scanned ${s.scanned} of ${s.ports.length} ports',
            ),
          )
        : null;
    final error = s.error == null
        ? null
        : Padding(
            padding: const EdgeInsets.only(top: 12),
            child: PulseErrorBanner(
              title: s.target.isEmpty ? "Couldn't scan" : "Couldn't scan ${s.target}",
              message: s.error,
              onRetry: s.running || _target.text.trim().isEmpty ? null : _scan,
            ),
          );

    final cells = portCells(ports, results);
    final per = portsPerCell(ports.length);
    final columns = cells.length <= 66 ? (compact ? 22 : 33) : 32;
    final mapLabel =
        'Port map, ${current ? '${s.scanned} of ${ports.length} scanned, ${open.length} open, ${filtered.length} filtered' : '${ports.length} ports, not scanned'}';
    final map = PulseCard(
      padding: compact ? const EdgeInsets.fromLTRB(16, 14, 16, 16) : const EdgeInsets.fromLTRB(18, 16, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 6,
            children: [
              Text(
                'Port map · $rangeTitle',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.type.titleMedium,
              ),
              Wrap(
                spacing: compact ? 10 : 16,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const PortLegend('Open', cell: PortCell.open),
                  const PortLegend('Filtered', cell: PortCell.filtered),
                  if (!compact) const PortLegend('Closed', cell: PortCell.closed),
                  if (!compact && ports.isNotEmpty)
                    Text(
                      '· each cell = $per port${per == 1 ? '' : 's'} · ${s.concurrency} connections',
                      style: context.type.labelMedium!.copyWith(color: context.colors.onSurfaceVariant),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (ports.isEmpty)
            Text(
              'Enter a valid custom range to see the map.',
              style: context.type.bodySmall!.copyWith(color: context.colors.onSurfaceVariant),
            )
          else
            PortMap(
              cells: cells,
              columns: columns,
              maxCell: compact ? 11 : 21,
              gap: compact ? 3.5 : 4,
              semanticLabel: mapLabel,
            ),
        ],
      ),
    );

    final shown = [...open, ...filtered.take(50)];
    final more = filtered.length - (shown.length - open.length);
    final resultsList = shown.isEmpty ? null : _ResultsList(results: shown, compact: compact, moreFiltered: more);
    final noOpen = done && open.isEmpty
        ? PulseEmptyState(
            title: 'No open ports found',
            message:
                'Scanned ${s.scanned} ports (${s.rangeLabel == 'COMMON' ? 'common' : s.rangeLabel}) on ${s.address ?? s.target} in $seconds s.',
            shape: PulseShape.clover4,
            icon: PulseIcons.shield,
          )
        : null;
    final idleHint = !current && s.error == null
        ? Padding(
            padding: const EdgeInsets.fromLTRB(8, 16, 8, 0),
            child: Text(
              'Pick a range and tap Scan. Pulse opens a TCP connection to each port: '
              'open ports accept it, closed ones refuse, filtered ones never answer.',
              textAlign: TextAlign.center,
              style: context.type.bodySmall!.copyWith(color: context.colors.onSurfaceVariant),
            ),
          )
        : null;

    final runLabel = s.running ? 'Stop' : 'Scan';
    final runIcon = s.running ? PulseIcons.stop : PulseIcons.play;

    if (compact) {
      return PulsePage(
        title: 'Port scan',
        backTo: Routes.tools,
        actions: [
          PulseIconButton(
            icon: runIcon,
            tooltip: s.running ? 'Stop scan' : 'Scan',
            style: PulseIconButtonStyle.pink,
            visualSize: 48,
            onPressed: _toggle,
          ),
        ],
        children: [
          Padding(padding: const EdgeInsets.only(top: 4), child: field),
          Padding(padding: const EdgeInsets.only(top: 12), child: group),
          ?customNote,
          ?progress,
          ?error,
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 16, 8, 0),
            child: _PhoneStats(open: open.length, filtered: filtered.length, seconds: seconds),
          ),
          Padding(padding: const EdgeInsets.only(top: 16), child: map),
          ?idleHint,
          ?noOpen,
          if (resultsList != null) Padding(padding: const EdgeInsets.only(top: 12), child: resultsList),
        ],
      );
    }

    return PulsePage(
      title: 'Port scan',
      actions: [PulseButton(label: runLabel, icon: runIcon, size: PulseButtonSize.large, onPressed: _toggle)],
      children: [
        LayoutBuilder(
          builder: (context, box) => box.maxWidth >= 700
              ? Row(
                  children: [
                    Expanded(child: field),
                    const SizedBox(width: 12),
                    SizedBox(width: 340, child: group),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [field, const SizedBox(height: 12), group],
                ),
        ),
        ?customNote,
        ?progress,
        ?error,
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: _TabletStats(
            scanned: current ? s.scanned : 0,
            total: ports.length,
            running: s.running,
            open: open.length,
            filtered: filtered.length,
            seconds: seconds,
          ),
        ),
        Padding(padding: const EdgeInsets.only(top: 16), child: map),
        ?idleHint,
        ?noOpen,
        if (resultsList != null) Padding(padding: const EdgeInsets.only(top: 12), child: resultsList),
      ],
    );
  }
}

/// Open (cookie9 pink), Filtered (clover4 lavender), Time (square lime).
class _PhoneStats extends StatelessWidget {
  const _PhoneStats({required this.open, required this.filtered, required this.seconds});
  final int open, filtered;
  final String seconds;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      const gap = 12.0;
      final size = ((box.maxWidth - gap * 2) / 3).clamp(72.0, 112.0);
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          PulsePop(
            child: PulseShapeStat(
              shape: PulseShape.cookie9,
              tone: PulseTone.pink,
              label: 'Open',
              value: '$open',
              size: size,
              motion: PulseShapeMotion.spin,
            ),
          ),
          PulsePop(
            delay: const Duration(milliseconds: 80),
            child: PulseShapeStat(
              shape: PulseShape.clover4,
              tone: PulseTone.lavender,
              label: 'Filtered',
              value: '$filtered',
              size: size,
              motion: PulseShapeMotion.wobble,
            ),
          ),
          PulsePop(
            delay: const Duration(milliseconds: 160),
            child: PulseShapeStat(
              shape: PulseShape.square,
              tone: PulseTone.lime,
              label: 'Time',
              value: seconds,
              unit: seconds == '—' ? null : 's',
              size: size,
            ),
          ),
        ],
      );
    },
  );
}

/// Scanned · Open · Filtered · Time cards with shape badges.
class _TabletStats extends StatelessWidget {
  const _TabletStats({
    required this.scanned,
    required this.total,
    required this.running,
    required this.open,
    required this.filtered,
    required this.seconds,
  });

  final int scanned, total, open, filtered;
  final bool running;
  final String seconds;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) => _row(context, box.maxWidth < 720));

  /// [tight]: four cards in a narrow tablet column (landscape Tab A9 next to
  /// the Tools pane) get smaller badges so the labels stay readable.
  Widget _row(BuildContext context, bool tight) {
    final c = context.colors;
    final b = tight ? 40.0 : 56.0;
    Widget card(int i, Widget badge, String label, String value, {String? unit}) => Expanded(
      child: PulseEntrance(
        index: i,
        child: Semantics(
          label: '$label $value ${unit ?? ''}',
          excludeSemantics: true,
          child: PulseCard(
            padding: tight ? const EdgeInsets.fromLTRB(10, 12, 8, 12) : const EdgeInsets.fromLTRB(14, 14, 12, 14),
            child: Row(
              children: [
                badge,
                SizedBox(width: tight ? 8 : 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.type.labelLarge!.copyWith(fontWeight: FontWeight.w600),
                      ),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: PulseNumber(
                          value,
                          unit: unit,
                          live: true,
                          unitScale: .6,
                          unitGap: 6,
                          style: pulseText(tight ? 24 : 30, 900, wdth: 115, height: 1.05),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return Row(
      children: [
        card(
          0,
          PulseContainerBadge(
            shape: PulseShape.circle,
            icon: PulseIcons.grid,
            color: c.surfaceContainerHighest,
            onColor: c.onSurface,
            size: b,
          ),
          'Scanned',
          '$scanned',
          unit: running ? '/ $total' : null,
        ),
        const SizedBox(width: 12),
        card(
          1,
          PulseShapeBadge(
            shape: PulseShape.cookie9,
            tone: PulseTone.pink,
            icon: PulseIcons.port,
            size: b,
            spin: PulseMotion.smallSpin,
          ),
          'Open',
          '$open',
        ),
        const SizedBox(width: 12),
        card(
          2,
          PulseShapeBadge(shape: PulseShape.clover4, tone: PulseTone.lavender, icon: PulseIcons.shield, size: b),
          'Filtered',
          '$filtered',
        ),
        const SizedBox(width: 12),
        card(
          3,
          PulseShapeBadge(shape: PulseShape.square, tone: PulseTone.lime, icon: PulseIcons.timer, size: b),
          'Time',
          seconds,
          unit: seconds == '—' ? null : 's',
        ),
      ],
    );
  }
}

String _serviceName(PortResult r) {
  final s = r.service;
  if (s == 'unknown') return 'Unknown';
  return s.length <= 6 && !s.contains(RegExp(r'[-/]')) ? s.toUpperCase() : s;
}

/// Results as a segmented list: port number, service and banner, state pill.
class _ResultsList extends StatelessWidget {
  const _ResultsList({required this.results, required this.compact, required this.moreFiltered});
  final List<PortResult> results;
  final bool compact;
  final int moreFiltered;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final n = results.length + (moreFiltered > 0 ? 1 : 0);
    Widget row(int i, PortResult r) {
      final isOpen = r.state == PortState.open;
      final banner = isOpen ? (r.banner ?? 'no banner') : 'no response';
      final service = _serviceName(r);
      final pill = PulsePill(
        isOpen ? 'Open' : 'Filtered',
        tone: isOpen ? PulsePillTone.pink : PulsePillTone.outline,
        height: compact ? 30 : 28,
      );
      final port = Text('${r.port}', maxLines: 1, style: pulseText(compact ? 22 : 26, 900, wdth: 110, height: 1));
      final body = compact
          ? Row(
              children: [
                SizedBox(
                  width: 72,
                  child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: port),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        service,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.type.titleMedium!.copyWith(fontSize: 15),
                      ),
                      Text(
                        banner,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.type.bodySmall!.copyWith(color: c.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                pill,
              ],
            )
          : Row(
              children: [
                SizedBox(
                  width: 96,
                  child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: port),
                ),
                SizedBox(
                  width: 130,
                  child: Text(service, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.type.titleMedium),
                ),
                Expanded(
                  child: Text(
                    banner,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.type.bodyMedium!.copyWith(color: c.onSurfaceVariant),
                  ),
                ),
                const SizedBox(width: 12),
                pill,
              ],
            );
      return Semantics(
        label: 'Port ${r.port}, $service, ${isOpen ? 'open' : 'filtered'}, $banner',
        excludeSemantics: true,
        child: Container(
          constraints: BoxConstraints(minHeight: compact ? 56 : 58),
          padding: EdgeInsets.fromLTRB(compact ? 16 : 18, 8, 16, 8),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(color: c.surfaceContainer, borderRadius: segmentedRadius(i, n)),
          child: body,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < results.length; i++) ...[
          if (i > 0) const SizedBox(height: 3),
          PulseEntrance(index: i, child: row(i, results[i])),
        ],
        if (moreFiltered > 0) ...[
          const SizedBox(height: 3),
          Container(
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(color: c.surfaceContainer, borderRadius: segmentedRadius(n - 1, n)),
            child: Text(
              '+ $moreFiltered more filtered',
              style: context.type.bodyMedium!.copyWith(color: c.onSurfaceVariant),
            ),
          ),
        ],
      ],
    );
  }
}

/// Custom range sheet: a spec field ("22,80,443,8000-8100"), quick presets,
/// live validation and the port count.
class _CustomRangeSheet extends StatefulWidget {
  const _CustomRangeSheet({required this.initial});
  final String initial;

  @override
  State<_CustomRangeSheet> createState() => _CustomRangeSheetState();
}

class _CustomRangeSheetState extends State<_CustomRangeSheet> {
  late final _c = TextEditingController(text: widget.initial);

  static const _quick = [
    ('Web', '80,443,8000,8080,8443'),
    ('Remote access', '22,23,3389,5900'),
    ('Databases', '1433,1521,3306,5432,6379,27017'),
    ('1–100', '1-100'),
  ];

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  ({int? count, String? error}) get _check {
    if (_c.text.trim().isEmpty) return (count: null, error: 'Enter at least one port.');
    try {
      final n = parsePortSpec(_c.text).length;
      if (n == 0) return (count: null, error: 'Enter at least one port.');
      if (n > 20000) return (count: n, error: 'Pick at most 20,000 ports per scan.');
      return (count: n, error: null);
    } on FormatException catch (e) {
      return (count: null, error: e.message);
    }
  }

  void _use() {
    if (_check.error == null) Navigator.of(context).pop(_c.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final check = _check;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Custom ports', style: context.type.titleLarge),
              const SizedBox(height: 4),
              Text(
                'Comma-separated ports and ranges, 1–65535.',
                style: context.type.bodySmall!.copyWith(color: c.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              PulseTargetField(
                controller: _c,
                hint: '22,80,443,8000-8100',
                icon: PulseIcons.port,
                keyboardType: TextInputType.text,
                autofocus: true,
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _use(),
                trailing: check.count == null ? null : '${check.count} port${check.count == 1 ? '' : 's'}',
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                child: Text(check.error ?? ' ', style: context.type.bodySmall!.copyWith(color: c.error)),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final (label, spec) in _quick)
                    PulseChip(
                      label: label,
                      small: true,
                      selected: _c.text.trim() == spec,
                      onTap: () => setState(() => _c.text = spec),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  PulseButton(
                    label: 'Cancel',
                    style: PulseButtonStyle.text,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 8),
                  PulseButton(label: 'Use range', onPressed: check.error == null ? _use : null),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
