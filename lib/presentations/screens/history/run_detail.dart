import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/format.dart';
import '../../../core/widgets/pulse/pulse.dart';
import '../../../data/db/app_database.dart';
import '../../../data/models/session_tool.dart';
import '../../../data/repositories/history_repository.dart';
import '../../../providers/history_provider.dart';
import '../../../providers/ping_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../services/export_service.dart';
import '../../../services/net/port_scanner.dart';
import '../trace/trace_widgets.dart';
import 'run_info.dart';

/// The detail of one stored run: badge + title, share / delete, a connected
/// row of summary tiles, the run's details for its tool, then Run again and
/// Copy as text. [compact] adds a back arrow and stacks the tiles 2 x 2.
class RunDetail extends ConsumerWidget {
  const RunDetail({super.key, required this.session, this.compact = false, this.onClose});

  final Session session;
  final bool compact;

  /// Pops the pushed phone page (back arrow, after delete / run again).
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = RunInfo(session);
    final pad = compact ? PulseLayout.gutter : PulseLayout.tabletPadding;
    final body = <Widget>[
      _Header(info: info, compact: compact),
      const SizedBox(height: 20),
      _SummaryTiles(tiles: info.tiles, compact: compact),
      ..._bodyFor(context, info),
    ];
    final actions = Padding(
      padding: EdgeInsets.fromLTRB(pad, 16, pad, compact ? 24 : 20),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          PulseButton(
            label: 'Run again',
            icon: PulseIcons.refresh,
            size: PulseButtonSize.large,
            onPressed: () => _rerun(context, ref, info),
          ),
          PulseButton(
            label: 'Copy as text',
            icon: PulseIcons.copy,
            style: PulseButtonStyle.tonal,
            size: PulseButtonSize.large,
            onPressed: () {
              Clipboard.setData(ClipboardData(text: HistoryRepository.report(session)));
              ScaffoldMessenger.maybeOf(context)
                ?..hideCurrentSnackBar()
                ..showSnackBar(const SnackBar(content: Text('Run copied as text')));
            },
          ),
        ],
      ),
    );
    final top = Padding(
      padding: EdgeInsets.fromLTRB(compact ? 4 : 0, 0, 8, 0),
      child: Row(
        children: [
          if (onClose != null) PulseBackButton(onPressed: onClose!),
          const Spacer(),
          ..._headerActions(context, ref, info),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (compact) SizedBox(height: 64, child: top),
        Expanded(
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(pad, compact ? 0 : 20, pad, 0),
                sliver: SliverList.list(
                  children: [for (var i = 0; i < body.length; i++) PulseEntrance(index: i, child: body[i])],
                ),
              ),
              SliverFillRemaining(
                hasScrollBody: false,
                child: Align(alignment: Alignment.bottomLeft, child: actions),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _headerActions(BuildContext context, WidgetRef ref, RunInfo info) => [
    PulseIconButton(icon: PulseIcons.share, tooltip: 'Save report', onPressed: () => _saveReport(context, ref)),
    PulseIconButton(icon: PulseIcons.trash, tooltip: 'Delete run', onPressed: () => _delete(context, ref, info)),
  ];

  Future<void> _saveReport(BuildContext context, WidgetRef ref) async {
    final s = session;
    final settings = ref.read(settingsProvider);
    final messenger = ScaffoldMessenger.of(context);
    final name = (s.label ?? s.target).replaceAll(RegExp(r'[^A-Za-z0-9.-]+'), '_');
    try {
      final path = await const ExportService().save(
        fileName: 'pulse-${s.tool}-$name-${s.id}.txt',
        content: HistoryRepository.report(s),
        settings: settings,
      );
      if (path != null) messenger.showSnackBar(SnackBar(content: Text('Saved $path')));
    } on Object catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Could not save the report: $e')));
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, RunInfo info) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this run?'),
        content: Text('${info.tool.name} of ${info.title} from ${info.when} is removed from History.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: context.colors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(historyRepositoryProvider).delete(session.id);
    ref.read(selectedSessionIdProvider.notifier).select(null);
    HapticFeedback.lightImpact();
    onClose?.call();
  }

  Future<void> _rerun(BuildContext context, WidgetRef ref, RunInfo info) async {
    final s = session;
    if (info.kind == SessionTool.ping) {
      await ref.read(pingBoardProvider.notifier).start(s.target, name: s.label, params: info.pingParams);
      onClose?.call();
      if (context.mounted) context.go(info.tool.route);
      return;
    }
    onClose?.call();
    if (context.mounted) context.go('${info.tool.route}?target=${Uri.encodeComponent(s.target)}');
  }

  List<Widget> _bodyFor(BuildContext context, RunInfo info) {
    switch (info.kind) {
      case SessionTool.trace:
        return _traceBody(context, info);
      case SessionTool.ping:
        return _pingBody(context, info);
      case SessionTool.speed:
        return _speedBody(context, info);
      case SessionTool.ports:
        return _portsBody(context, info);
      case SessionTool.loss:
        return _lossBody(context, info);
      case SessionTool.lan:
        return _lanBody(context, info);
      case SessionTool.geo:
        return _geoBody(context, info);
      case null:
        return [
          const PulseSectionLabel('Details'),
          _KeyValues([('Result', info.session.summary), ('Target', info.session.target)]),
        ];
    }
  }

  // ---------------------------------------------------------------------------
  // Per-tool bodies
  // ---------------------------------------------------------------------------

  /// Same widgets as the live Traceroute screen, fed the stored hops, so a
  /// saved run reads exactly as it did when it ran.
  List<Widget> _traceBody(BuildContext context, RunInfo info) {
    final trace = info.trace;
    if (trace.isEmpty) return const [];
    return [
      const SizedBox(height: 12),
      TraceRouteCard(insights: trace),
      if (trace.highlights.isNotEmpty) ...[const PulseSectionLabel('Highlights'), TraceHighlights(insights: trace)],
      const PulseSectionLabel('Hops'),
      TraceHopList(insights: trace),
    ];
  }

  List<Widget> _pingBody(BuildContext context, RunInfo info) {
    final replies = info.pingReplies;
    final stats = info.pingStats;
    final params = info.pingParams;
    final recent = replies.length > 60 ? replies.sublist(replies.length - 60) : replies;
    final values = [for (final r in recent) r.received ? r.rttMs : null];
    final present = values.whereType<double>();
    final avg = present.isEmpty ? null : present.reduce((a, b) => a + b) / present.length;
    return [
      if (values.isNotEmpty) ...[
        const SizedBox(height: 12),
        PulseCard(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Last ${values.length} replies',
                style: context.type.labelMedium!.copyWith(color: context.colors.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              PulseBars(
                values: values,
                height: 72,
                barWidth: 8,
                fill: true,
                average: avg,
                semanticLabel:
                    'Last ${values.length} pings, average ${fmtMs(avg)} ms, '
                    'max ${fmtMs(present.isEmpty ? null : present.reduce(math.max))} ms, '
                    '${values.where((v) => v == null).length} lost',
              ),
            ],
          ),
        ),
      ],
      const PulseSectionLabel('Details'),
      _KeyValues([
        if (info.session.label != null) ('Host', info.session.target),
        if (stats != null) ('Min / max', '${fmtMs(stats.min)} / ${fmtMs(stats.max)} ms'),
        if (stats != null) ('Received', '${stats.received} of ${stats.sent}'),
        if (params != null) ('Interval', '${params.intervalMs / 1000} s'.replaceAll('.0 ', ' ')),
        if (params != null) ('Packet size', '${params.packetSize} bytes'),
        if (params != null) ('Timeout', '${params.timeoutSec} s'),
        ('Duration', info.durationText),
      ]),
    ];
  }

  List<Widget> _speedBody(BuildContext context, RunInfo info) {
    final trend = HistoryRepository.trendOf(info.session);
    return [
      if (trend.isNotEmpty) ...[
        const SizedBox(height: 12),
        PulseCard(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Download samples',
                style: context.type.labelMedium!.copyWith(color: context.colors.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              PulseBars(
                values: trend,
                height: 72,
                barWidth: 10,
                fill: true,
                color: context.colors.primary,
                semanticLabel:
                    '${trend.length} download samples, peak ${trend.reduce(math.max).toStringAsFixed(1)} Mbps',
              ),
            ],
          ),
        ),
      ],
      const PulseSectionLabel('Details'),
      _KeyValues([
        ('Server', info.session.target),
        if (info.payload['colo'] != null) ('Data centre', '${info.payload['colo']}'),
        ('Duration', info.durationText),
      ]),
    ];
  }

  List<Widget> _portsBody(BuildContext context, RunInfo info) {
    final open = info.openPorts;
    final c = context.colors;
    return [
      PulseSectionLabel('Open ports · ${open.length}'),
      if (open.isEmpty)
        PulseCard(
          child: Text(
            'No open ports in this range.',
            style: context.type.bodyMedium!.copyWith(color: c.onSurfaceVariant),
          ),
        )
      else
        PulseSegmentedList(
          animate: false,
          children: [
            for (final p in open)
              PulseListItem(
                leading: const PulseShapeBadge(shape: PulseShape.cookie9, tone: PulseTone.pink, size: 36),
                title: '${p['port']} · ${kPortServices[p['port']] ?? 'unknown'}',
                subtitle: (p['banner'] as String?)?.trim().isNotEmpty == true ? (p['banner'] as String).trim() : null,
                trailing: p['ms'] == null
                    ? null
                    : PulseNumber(
                        fmtMs((p['ms'] as num).toDouble()),
                        unit: 'ms',
                        unitScale: .65,
                        style: pulseNumber(16),
                      ),
              ),
          ],
        ),
      const PulseSectionLabel('Details'),
      _KeyValues([
        if (info.payload['address'] != null) ('Address', '${info.payload['address']}'),
        if (info.payload['range'] != null) ('Range', '${info.payload['range']}'),
        ('Duration', info.durationText),
      ]),
    ];
  }

  List<Widget> _lossBody(BuildContext context, RunInfo info) {
    final packets = info.packets;
    final values = [
      for (final p in packets)
        if (p['state'] != 'pending') (p['state'] == 'lost' ? null : (p['rtt'] as num?)?.toDouble()),
    ];
    final verdict = info.payload['verdict'] as String?;
    return [
      if (values.isNotEmpty) ...[
        const SizedBox(height: 12),
        PulseCard(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${values.length} packets',
                style: context.type.labelMedium!.copyWith(color: context.colors.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              PulseBars(
                values: values,
                height: 64,
                barWidth: 6,
                gap: 2,
                fill: true,
                semanticLabel: '${values.length} packets, ${values.where((v) => v == null).length} lost',
              ),
              if (verdict != null) ...[const SizedBox(height: 12), Text(verdict, style: context.type.bodyMedium)],
            ],
          ),
        ),
      ],
      const PulseSectionLabel('Details'),
      _KeyValues([
        if (info.payload['address'] != null) ('Address', '${info.payload['address']}'),
        if (info.payload['late'] != null) ('Late replies', '${info.payload['late']}'),
        if (info.payload['burst'] != null) ('Longest burst', '${info.payload['burst']} lost in a row'),
        if (info.payload['rate'] != null) ('Rate', '${info.payload['rate']} per second'),
        ('Duration', info.durationText),
      ]),
    ];
  }

  List<Widget> _lanBody(BuildContext context, RunInfo info) {
    final devices = info.devices;
    return [
      PulseSectionLabel('Devices · ${devices.length}'),
      PulseSegmentedList(
        animate: false,
        children: [
          for (final d in devices)
            PulseListItem(
              leading: const PulseShapeBadge(
                shape: PulseShape.pill,
                tone: PulseTone.lime,
                icon: PulseIcons.lan,
                size: 36,
              ),
              title: (d['name'] as String?)?.isNotEmpty == true ? d['name'] as String : '${d['ip']}',
              subtitle: [
                if ((d['name'] as String?)?.isNotEmpty == true) '${d['ip']}',
                if (d['vendor'] != null) '${d['vendor']}',
                if (d['mac'] != null) '${d['mac']}',
                if (d['type'] != null) '${d['type']}',
              ].join(' · '),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (d['new'] == true) ...[const PulsePill('New', tone: PulsePillTone.pink), const SizedBox(width: 8)],
                  if (d['rtt'] != null)
                    PulseNumber(
                      fmtMs((d['rtt'] as num).toDouble()),
                      unit: 'ms',
                      unitScale: .65,
                      style: pulseNumber(16),
                      color: context.pulse.latencyColor((d['rtt'] as num).toDouble()),
                    ),
                ],
              ),
            ),
        ],
      ),
    ];
  }

  List<Widget> _geoBody(BuildContext context, RunInfo info) {
    final g = info.geo;
    String? s(String k) => (g[k] as String?)?.isNotEmpty == true ? g[k] as String : null;
    final lat = (g['lat'] as num?)?.toDouble(), lon = (g['lon'] as num?)?.toDouble();
    final place = [s('city'), s('region'), s('country')].whereType<String>().toSet().join(', ');
    return [
      const PulseSectionLabel('Details'),
      _KeyValues([
        if (s('ip') != null) ('IP address', s('ip')!),
        if (place.isNotEmpty) ('Location', place),
        if (s('isp') != null) ('ISP', s('isp')!),
        if (s('org') != null && s('org') != s('isp')) ('Organisation', s('org')!),
        if (s('asn') != null) ('ASN', [s('asn'), s('asName')].whereType<String>().join(' · ')),
        if (s('timezone') != null) ('Time zone', s('timezone')!),
        if (lat != null && lon != null) ('Coordinates', '${lat.toStringAsFixed(4)}, ${lon.toStringAsFixed(4)}'),
        if (info.payload['hops'] != null) ('Hops away', '${info.payload['hops']}'),
        if (s('reverse') != null) ('Reverse DNS', s('reverse')!),
        if (s('source') != null) ('Source', s('source')!),
      ]),
    ];
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.info, required this.compact});
  final RunInfo info;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tool = info.tool;
    return Row(
      children: [
        PulseShapeBadge(shape: tool.shape, tone: tool.tone, icon: tool.icon, size: compact ? 56 : 64),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(
                  info.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: compact ? context.type.headlineMedium : context.type.headlineLarge,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                [tool.name, info.when, if (info.session.label != null) info.session.target].join(' · '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.type.bodyMedium!.copyWith(color: c.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Connected row of summary tiles coloured per kit: pink, lime, lavender,
/// neutral. Two rows of two on narrow widths.
class _SummaryTiles extends StatelessWidget {
  const _SummaryTiles({required this.tiles, required this.compact});
  final List<RunTile> tiles;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final n = tiles.length;
        final grid = box.maxWidth < 560 && n > 2;
        if (!grid) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < n; i++) ...[
                if (i > 0) const SizedBox(width: 12),
                Expanded(
                  child: _Tile(
                    tile: tiles[i],
                    radius: BorderRadius.horizontal(
                      left: Radius.circular(i == 0 ? 28 : 8),
                      right: Radius.circular(i == n - 1 ? 28 : 8),
                    ),
                    large: !compact,
                  ),
                ),
              ],
            ],
          );
        }
        BorderRadius r(int i) {
          const big = Radius.circular(28), small = Radius.circular(8);
          return BorderRadius.only(
            topLeft: i == 0 ? big : small,
            topRight: i == 1 ? big : small,
            bottomLeft: i == 2 ? big : small,
            bottomRight: i == 3 || (i == 2 && n == 3) ? big : small,
          );
        }

        Widget row(int a) => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _Tile(tile: tiles[a], radius: r(a), large: false),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: a + 1 < n ? _Tile(tile: tiles[a + 1], radius: r(a + 1), large: false) : const SizedBox(),
            ),
          ],
        );
        return Column(children: [row(0), const SizedBox(height: 6), if (n > 2) row(2)]);
      },
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.tile, required this.radius, required this.large});
  final RunTile tile;
  final BorderRadius radius;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (Color bg, Color fg) = switch (tile.tone) {
      RunTileTone.pink => (PulseTone.pink.fill(context), PulseTone.pink.on(context)),
      RunTileTone.lime => (PulseTone.lime.fill(context), PulseTone.lime.on(context)),
      RunTileTone.lavender => (PulseTone.lavender.fill(context), PulseTone.lavender.on(context)),
      RunTileTone.neutral => (c.surfaceContainerHigh, c.onSurface),
    };
    return Semantics(
      label: '${tile.label} ${tile.value} ${tile.unit ?? ''}',
      excludeSemantics: true,
      child: Container(
        constraints: BoxConstraints(minHeight: large ? 88 : 76),
        padding: EdgeInsets.fromLTRB(18, large ? 16 : 12, 14, large ? 18 : 14),
        decoration: BoxDecoration(color: bg, borderRadius: radius),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              tile.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: pulseText(13, 700).copyWith(color: fg),
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: PulseNumber(
                tile.value,
                unit: tile.unit,
                unitScale: .7,
                unitGap: 6,
                style: pulseText(large ? 34 : 28, 900, wdth: 110, height: 1.1),
                color: fg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Key / value rows (overline key, value as the title).
class _KeyValues extends StatelessWidget {
  const _KeyValues(this.rows);
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) => PulseSegmentedList(
    animate: false,
    children: [
      for (final r in rows)
        PulseListItem(
          overline: r.$1,
          title: r.$2.isEmpty ? '—' : r.$2,
          titleStyle: context.type.bodyLarge!.copyWith(fontWeight: FontWeight.w600),
        ),
    ],
  );
}
