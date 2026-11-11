import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/widgets/pulse/pulse.dart';
import '../../../providers/monitor_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../services/background/background_service.dart';
import '../../../services/background/notifications.dart';
import '../../navigation/destinations.dart';
import 'monitor_sheets.dart';
import 'monitor_widgets.dart';

/// 12 Monitor: uptime of every watched host over 24 h / 7 d / 30 d, the
/// current latency, a block strip per target, and incidents.
///
/// Phone: status strip, uptime cookie + stat column, range group, targets.
/// Tablet: header with status strip, range group and "Add target"; stats row;
/// targets on the left and an Incidents card on the right.
class MonitorScreen extends ConsumerWidget {
  const MonitorScreen({super.key});

  /// Content width from which the full tablet layout (kit header, two
  /// columns) fits; narrower tablets / windows get a single column.
  static const _wideFrom = 820.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(monitorOverviewProvider);
    final overview = async.value;
    final rows = overview?.rows ?? const <TargetRow>[];
    final compact = context.isCompact;

    void alerts() => context.push(Routes.alerts);
    void add() => showAddTargetSheet(context);

    final bell = PulseIconButton(icon: PulseIcons.bell, tooltip: 'Alert rules', onPressed: alerts);

    if (overview == null) {
      return PulsePage(
        title: 'Monitor',
        backTo: Routes.tools,
        actions: [bell],
        body: Center(
          child: async.hasError
              ? Padding(
                  padding: EdgeInsets.all(context.pagePadding),
                  child: PulseErrorBanner(
                    title: 'Couldn\'t read monitoring data',
                    message: '${async.error}',
                    onRetry: () => ref.invalidate(monitorOverviewProvider),
                  ),
                )
              : const SizedBox(width: 220, child: PulseWavyBar(value: .4, semanticLabel: 'Loading monitor data')),
        ),
      );
    }

    if (rows.isEmpty) {
      return PulsePage(
        title: 'Monitor',
        backTo: Routes.tools,
        actions: [bell],
        body: Center(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: PulseEmptyState(
                title: 'Nothing watched yet',
                message:
                    'Add a host and Pulse checks it '
                    '${monitorCadence(ref.watch(settingsProvider.select((s) => s.monitorIntervalSec)), background: ref.watch(settingsProvider.select((s) => s.monitorInBackground)))}.',
                icon: PulseIcons.monitor,
                action: PulseButton(label: 'Add target', icon: PulseIcons.plus, onPressed: add),
              ),
            ),
          ),
        ),
      );
    }

    if (compact) {
      return PulsePage(
        title: 'Monitor',
        backTo: Routes.tools,
        actions: [
          bell,
          PulseButton(label: 'Add', icon: PulseIcons.plus, size: PulseButtonSize.small, onPressed: add),
        ],
        children: [
          const _NotificationsOffBanner(),
          const _StatusStrip(),
          const SizedBox(height: 12),
          _PhoneStats(overview: overview),
          const SizedBox(height: 12),
          const _RangeGroup(),
          const SizedBox(height: 12),
          _TargetList(rows: rows, blocks: 24, wide: false),
          const SizedBox(height: 12),
          const _Footer(),
          const SizedBox(height: 4),
          _IncidentsSection(overview: overview),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, box) {
        final wide = box.maxWidth >= _wideFrom;
        if (!wide) {
          // Portrait tablet or narrow window: tablet header, one column.
          return PulsePage(
            title: 'Monitor',
            backTo: Routes.tools,
            actions: [
              bell,
              PulseButton(label: 'Add target', icon: PulseIcons.plus, onPressed: add),
            ],
            children: [
              const _NotificationsOffBanner(),
              Row(
                children: [
                  const Expanded(child: _StatusStrip()),
                  const SizedBox(width: 12),
                  const SizedBox(width: 220, child: _RangeGroup()),
                ],
              ),
              const SizedBox(height: 16),
              _TabletStats(overview: overview),
              const SizedBox(height: 14),
              _TargetList(rows: rows, blocks: 36, wide: true),
              const SizedBox(height: 12),
              const _Footer(),
              const SizedBox(height: 12),
              _IncidentsCard(overview: overview, fill: false),
            ],
          );
        }
        return PulsePage(
          title: 'Monitor',
          titleWidget: Row(
            children: [
              Text('Monitor', style: context.type.headlineMedium),
              const SizedBox(width: 12),
              const Flexible(child: _StatusStrip(compactPill: true)),
            ],
          ),
          backTo: Routes.tools,
          actions: [
            const SizedBox(width: 200, child: _RangeGroup()),
            PulseButton(label: 'Add target', icon: PulseIcons.plus, size: PulseButtonSize.large, onPressed: add),
          ],
          body: LayoutBuilder(
            builder: (context, inner) {
              const pad = PulseLayout.tabletPadding;
              // Short windows scroll instead of squeezing the rows.
              if (inner.maxHeight < 520) {
                return ListView(
                  padding: const EdgeInsets.fromLTRB(pad, 0, pad, pad),
                  children: [
                    const _NotificationsOffBanner(),
                    _TabletStats(overview: overview),
                    const SizedBox(height: 14),
                    _TargetList(rows: rows, blocks: 36, wide: true),
                    const SizedBox(height: 12),
                    const _Footer(),
                    const SizedBox(height: 12),
                    _IncidentsCard(overview: overview, fill: false),
                  ],
                );
              }
              return Padding(
                padding: const EdgeInsets.fromLTRB(pad, 0, pad, pad),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _NotificationsOffBanner(),
                    PulseEntrance(child: _TabletStats(overview: overview)),
                    const SizedBox(height: 14),
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(child: _TargetList(rows: rows, blocks: 36, wide: true, fill: true)),
                                const SizedBox(height: 10),
                                const Padding(padding: EdgeInsets.only(left: 4), child: _Footer()),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          SizedBox(
                            width: inner.maxWidth >= 1100 ? 320 : 280,
                            child: PulseEntrance(index: 2, child: _IncidentsCard(overview: overview, fill: true)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Notifications blocked (Android / iOS background monitoring)
// ---------------------------------------------------------------------------

/// Shown while background monitoring runs but notifications are blocked: the
/// service's status notification is hidden and alerts can't reach the user.
/// Re-checks when Pulse returns from system settings.
class _NotificationsOffBanner extends ConsumerStatefulWidget {
  const _NotificationsOffBanner();

  @override
  ConsumerState<_NotificationsOffBanner> createState() => _NotificationsOffBannerState();
}

class _NotificationsOffBannerState extends ConsumerState<_NotificationsOffBanner> with WidgetsBindingObserver {
  bool _blocked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    if (!BackgroundMonitor.supported) return;
    final blocked = !await Permission.notification.isGranted;
    if (!mounted || blocked == _blocked) return;
    final allowed = _blocked && !blocked;
    setState(() => _blocked = blocked);
    if (allowed) await ref.read(monitorRunnerProvider.notifier).refreshService();
  }

  Future<void> _allow() async {
    if (!await PulseNotifications.requestPermission()) await openAppSettings();
    await _check();
  }

  @override
  Widget build(BuildContext context) {
    final service = ref.watch(monitorRunnerProvider.select((r) => r.mode == MonitorMode.service));
    if (!_blocked || !service) return const SizedBox.shrink();
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PulseCard(
        color: c.surfaceContainerHigh,
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Row(
          children: [
            PulseIcon(PulseIcons.bell, size: 22, color: c.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Notifications are off', style: context.type.titleSmall),
                  Text(
                    "Monitoring still runs, but alerts and the monitoring status can't be shown.",
                    style: context.type.bodySmall!.copyWith(color: c.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            PulseButton(label: 'Allow', style: PulseButtonStyle.tonal, size: PulseButtonSize.small, onPressed: _allow),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Status strip
// ---------------------------------------------------------------------------

/// Live dot, "Running · 6 targets", options and a tonal Pause / Resume.
class _StatusStrip extends ConsumerWidget {
  const _StatusStrip({this.compactPill = false});

  /// Tablet header variant: a 44 dp pill next to the title.
  final bool compactPill;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final run = ref.watch(monitorRunnerProvider);
    final runner = ref.read(monitorRunnerProvider.notifier);
    final rows = ref.watch(monitorOverviewProvider).value?.rows ?? const <TargetRow>[];
    final targets = rows.where((r) => r.target.enabled).length;
    final paused = run.mode == MonitorMode.paused;
    // The strip also holds the tune and Pause buttons, so the long "Running in
    // background · N targets" only fits on wide layouts: show the longest
    // label that fits the space left (phones, tablets beside the Tools pane).
    final short = monitorStatusShort(run, targets);
    final labels = [if (!compactPill) monitorStatusLabel(run, targets), short, short.split(' · ').first];
    final dot = run.live
        ? PulseLiveDot(color: c.tertiary, size: 8)
        : Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: c.outline, width: 1.5),
            ),
          );
    final pause = PulseButton(
      label: paused ? 'Resume' : 'Pause',
      icon: paused ? PulseIcons.play : PulseIcons.pause,
      style: PulseButtonStyle.tonal,
      size: PulseButtonSize.small,
      onPressed: runner.togglePaused,
    );
    final options = PulseIconButton(
      icon: PulseIcons.tune,
      tooltip: 'Monitoring options',
      visualSize: 40,
      iconSize: 20,
      onPressed: () => showMonitorOptionsSheet(context),
    );
    return Semantics(
      container: true,
      liveRegion: true,
      child: Container(
        height: compactPill ? 52 : null,
        padding: EdgeInsets.fromLTRB(16, compactPill ? 0 : 6, 6, compactPill ? 0 : 6),
        decoration: BoxDecoration(
          color: c.surfaceContainer,
          borderRadius: BorderRadius.circular(compactPill ? 26 : 24),
        ),
        child: Row(
          mainAxisSize: compactPill ? MainAxisSize.min : MainAxisSize.max,
          children: [
            dot,
            const SizedBox(width: 10),
            Flexible(
              fit: compactPill ? FlexFit.loose : FlexFit.tight,
              child: _FittingLabel(labels, style: context.type.titleSmall!.copyWith(color: c.onSurface)),
            ),
            const SizedBox(width: 4),
            options,
            pause,
          ],
        ),
      ),
    );
  }
}

/// One line of text: the first of [labels] that fits the width, else the
/// last one ellipsized.
class _FittingLabel extends StatelessWidget {
  const _FittingLabel(this.labels, {required this.style});

  final List<String> labels;
  final TextStyle style;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final scaler = MediaQuery.textScalerOf(context);
      final direction = Directionality.of(context);
      final label = labels.firstWhere((l) {
        final painter = TextPainter(
          text: TextSpan(text: l, style: style),
          maxLines: 1,
          textScaler: scaler,
          textDirection: direction,
        )..layout();
        final fits = painter.width <= constraints.maxWidth;
        painter.dispose();
        return fits;
      }, orElse: () => labels.last);
      return Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: style);
    },
  );
}

// ---------------------------------------------------------------------------
// Range + stats
// ---------------------------------------------------------------------------

class _RangeGroup extends ConsumerWidget {
  const _RangeGroup();

  @override
  Widget build(BuildContext context, WidgetRef ref) => PulseButtonGroup<MonitorRange>(
    small: true,
    segments: [for (final r in MonitorRange.values) PulseSegment(r, rangeLabel(r))],
    selected: ref.watch(monitorRangeProvider),
    onChanged: ref.read(monitorRangeProvider.notifier).set,
  );
}

class _UptimeCookie extends ConsumerWidget {
  const _UptimeCookie({required this.uptime});
  final double? uptime;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(monitorRangeProvider);
    return PulsePop(
      child: PulseShapeStat(
        shape: PulseShape.cookie12,
        tone: PulseTone.lime,
        label: 'Uptime ${rangeTitle(range)}',
        value: pctLabel(uptime),
        size: 150,
        motion: PulseShapeMotion.spin,
      ),
    );
  }
}

List<PulseStat> _stats(BuildContext context, MonitorOverview o) => [
  PulseStat('Avg latency', msLabel(o.avgMs), unit: o.avgMs == null ? null : 'ms'),
  PulseStat('Incidents', '${o.incidents}', color: o.incidents == 0 ? context.colors.tertiary : context.colors.primary),
  PulseStat('Checks', '${o.checks}'),
];

class _PhoneStats extends StatelessWidget {
  const _PhoneStats({required this.overview});
  final MonitorOverview overview;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      _UptimeCookie(uptime: overview.uptime),
      const SizedBox(width: 10),
      Expanded(child: PulseStatRow(vertical: true, valueSize: 22, stats: _stats(context, overview))),
    ],
  );
}

class _TabletStats extends StatelessWidget {
  const _TabletStats({required this.overview});
  final MonitorOverview overview;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final stats = _stats(context, overview);
    return SizedBox(
      height: 150,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _UptimeCookie(uptime: overview.uptime),
          for (final s in stats) ...[
            const SizedBox(width: 12),
            Expanded(
              child: Semantics(
                label: '${s.label} ${s.value} ${s.unit ?? ''}',
                excludeSemantics: true,
                child: PulseCard(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(s.label, style: context.type.labelMedium!.copyWith(color: c.onSurfaceVariant)),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.bottomLeft,
                        child: PulseNumber(
                          s.value,
                          unit: s.unit,
                          live: true,
                          unitScale: .85,
                          unitGap: 8,
                          color: s.color,
                          style: pulseText(44, 900, wdth: 115, height: 1),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Targets
// ---------------------------------------------------------------------------

class _TargetList extends StatelessWidget {
  const _TargetList({required this.rows, required this.blocks, required this.wide, this.fill = false});
  final List<TargetRow> rows;
  final int blocks;
  final bool wide;

  /// Stretch the rows to fill the available height (tablet).
  final bool fill;

  @override
  Widget build(BuildContext context) {
    final n = rows.length;
    Widget tile(int i, {double minHeight = 60}) => PulseEntrance(
      index: i + 1,
      child: _TargetTile(row: rows[i], index: i, count: n, blocks: blocks, wide: wide, minHeight: minHeight),
    );
    if (!fill) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < n; i++) ...[if (i > 0) const SizedBox(height: 3), tile(i, minHeight: wide ? 72 : 60)],
        ],
      );
    }
    return LayoutBuilder(
      builder: (context, box) {
        final per = ((box.maxHeight - 3 * (n - 1)) / n).clamp(64.0, 92.0);
        return ListView.separated(
          padding: EdgeInsets.zero,
          itemCount: n,
          separatorBuilder: (_, _) => const SizedBox(height: 3),
          itemBuilder: (context, i) => SizedBox(
            height: per,
            child: tile(i, minHeight: per),
          ),
        );
      },
    );
  }
}

class _TargetTile extends StatelessWidget {
  const _TargetTile({
    required this.row,
    required this.index,
    required this.count,
    required this.blocks,
    required this.wide,
    required this.minHeight,
  });

  final TargetRow row;
  final int index, count, blocks;
  final bool wide;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = row.target;
    final up = pctLabel(row.uptime);
    final state = !t.enabled
        ? 'Paused'
        : row.nowDown
        ? 'No reply'
        : null;
    final sub = wide
        ? [if (t.name.isNotEmpty) t.name, ?state].join(' · ')
        : [if (t.name.isNotEmpty) t.name, state ?? up].join(' · ');
    final value = !t.enabled
        ? PulseIcon(PulseIcons.pause, size: 18, color: c.onSurfaceVariant)
        : row.nowDown
        ? const DashedRing(size: 16)
        : PulseNumber(
            msLabel(row.nowMs),
            unit: wide && row.nowMs != null ? 'ms' : null,
            unitScale: .6,
            live: true,
            style: pulseNumber(wide ? 26 : 20),
          );
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          t.host,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.type.titleMedium!.copyWith(fontSize: wide ? 17 : 15),
        ),
        if (sub.isNotEmpty)
          Text(
            sub,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.type.bodySmall!.copyWith(color: c.onSurfaceVariant, fontSize: wide ? 14 : 13),
          ),
      ],
    );
    return Opacity(
      opacity: t.enabled ? 1 : .6,
      child: SegmentedTile(
        index: index,
        count: count,
        minHeight: minHeight,
        padding: EdgeInsets.symmetric(horizontal: wide ? 18 : 16, vertical: 8),
        semanticLabel:
            '${t.host}${t.name.isEmpty ? '' : ', ${t.name}'}, uptime $up, '
            '${state ?? 'now ${msLabel(row.nowMs)} milliseconds'}',
        onTap: () => showTargetSheet(context, t),
        child: ExcludeSemantics(
          child: Row(
            children: [
              SizedBox(width: wide ? 150 : 118, child: text),
              SizedBox(width: wide ? 16 : 12),
              Expanded(
                child: UptimeStrip(blocks: row.blocks, count: blocks, height: wide ? 26 : 22, maxGap: wide ? 3 : 2),
              ),
              if (wide) ...[
                const SizedBox(width: 16),
                SizedBox(
                  width: 52,
                  child: Text(
                    up,
                    textAlign: TextAlign.right,
                    style: context.type.bodyMedium!.copyWith(color: c.onSurfaceVariant),
                  ),
                ),
              ],
              SizedBox(width: wide ? 12 : 12),
              SizedBox(
                width: wide ? 84 : 42,
                child: Align(alignment: Alignment.centerRight, child: value),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Legend plus "checks every 1 min · last check 14:02".
class _Footer extends ConsumerWidget {
  const _Footer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final run = ref.watch(monitorRunnerProvider);
    final interval = ref.watch(settingsProvider.select((s) => s.monitorIntervalSec));
    final last = run.last == null ? '' : ' · last ${whenLabel(run.last!.at).toLowerCase()}';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: UptimeLegend(trailing: 'Every ${intervalLabel(interval)}$last'),
    );
  }
}

// ---------------------------------------------------------------------------
// Incidents
// ---------------------------------------------------------------------------

List<IncidentView> _inRange(WidgetRef ref) {
  final range = ref.watch(monitorRangeProvider);
  final since = DateTime.now().subtract(range.span);
  return [
    for (final i in ref.watch(incidentsProvider).value ?? const <IncidentView>[])
      if (i.ongoing || i.incident.startedAt.isAfter(since)) i,
  ];
}

String _hostOf(MonitorOverview o, IncidentView i) =>
    o.rows.where((r) => r.target.id == i.incident.targetId).firstOrNull?.target.host ?? i.targetName;

const _noIncidents = 'Outages, loss and latency spikes show up here, with a notification if you turn alerts on.';

/// Tablet: an Incidents card next to the targets.
class _IncidentsCard extends ConsumerWidget {
  const _IncidentsCard({required this.overview, required this.fill});
  final MonitorOverview overview;
  final bool fill;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = _inRange(ref);
    final header = Row(
      children: [
        Expanded(
          child: Semantics(header: true, child: Text('Incidents', style: context.type.titleLarge)),
        ),
        PulseIconButton(icon: PulseIcons.bell, tooltip: 'Alert rules', onPressed: () => context.push(Routes.alerts)),
      ],
    );
    final empty = PulseEmptyState(
      title: 'No incidents',
      message: _noIncidents,
      size: 96,
      action: PulseButton(
        label: 'Alert rules',
        icon: PulseIcons.bell,
        style: PulseButtonStyle.tonal,
        size: PulseButtonSize.small,
        onPressed: () => context.push(Routes.alerts),
      ),
    );
    final items = [
      for (final i in list)
        IncidentTile(view: i, host: _hostOf(overview, i), color: context.colors.surfaceContainerHigh, dense: true),
    ];
    return PulseCard(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: fill ? MainAxisSize.max : MainAxisSize.min,
        children: [
          Padding(padding: const EdgeInsets.only(left: 4), child: header),
          if (list.isEmpty)
            fill
                ? Expanded(
                    child: Center(child: SingleChildScrollView(child: empty)),
                  )
                : empty
          else if (fill)
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(right: 8),
                child: PulseSegmentedList(children: items),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: PulseSegmentedList(children: items),
            ),
        ],
      ),
    );
  }
}

/// Phone: incidents below the targets.
class _IncidentsSection extends ConsumerWidget {
  const _IncidentsSection({required this.overview});
  final MonitorOverview overview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = _inRange(ref);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PulseSectionLabel(
          'Incidents',
          trailing: PulseButton(
            label: 'Alert rules',
            icon: PulseIcons.bell,
            style: PulseButtonStyle.text,
            size: PulseButtonSize.small,
            onPressed: () => context.push(Routes.alerts),
          ),
        ),
        if (list.isEmpty)
          PulseCard(
            child: PulseEmptyState(title: 'No incidents', message: _noIncidents, size: 80),
          )
        else
          PulseSegmentedList(
            children: [for (final i in list) IncidentTile(view: i, host: _hostOf(overview, i))],
          ),
      ],
    );
  }
}
