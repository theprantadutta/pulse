import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/format.dart';
import '../../../core/widgets/pulse/pulse.dart';
import '../../../providers/ping_provider.dart';
import '../../navigation/destinations.dart';
import 'ping_configure.dart';
import 'ping_widgets.dart';

/// 02 Ping (home): every host on the multi-ping board.
///
/// * Phone: host chips, the selected (focused) host as the hero metric, its
///   stats, the other hosts as a segmented list and a Stop all / Start all FAB.
/// * Tablet: a grid of host cards; the focused host's card is highlighted.
///
/// Tapping a host opens Ping detail. `/ping?add=1` (the rail "+") opens the
/// add-host sheet once.
class PingScreen extends ConsumerStatefulWidget {
  const PingScreen({super.key});

  @override
  ConsumerState<PingScreen> createState() => _PingScreenState();
}

/// Only one add-host sheet at a time, even across screen rebuilds.
bool _addSheetOpen = false;

class _PingScreenState extends ConsumerState<PingScreen> {
  GoRouter? _router;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkAddQuery());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final router = GoRouter.maybeOf(context);
    if (router != _router) {
      _router?.routeInformationProvider.removeListener(_checkAddQuery);
      _router = router?..routeInformationProvider.addListener(_checkAddQuery);
    }
  }

  @override
  void dispose() {
    _router?.routeInformationProvider.removeListener(_checkAddQuery);
    super.dispose();
  }

  void _checkAddQuery() {
    final router = _router;
    if (router == null || !mounted || _addSheetOpen) return;
    final uri = router.routeInformationProvider.value.uri;
    if (uri.path != Routes.ping || uri.queryParameters['add'] != '1') return;
    _addSheetOpen = true;
    router.go(Routes.ping);
    showAddHostSheet(context).whenComplete(() => _addSheetOpen = false);
  }

  @override
  Widget build(BuildContext context) {
    final board = ref.watch(pingBoardProvider);
    final gateway = ref.watch(gatewayProvider).value;
    if (board.sessions.isEmpty) return const _EmptyPing();
    return context.isCompact ? _PhoneHome(board: board, gateway: gateway) : _TabletHome(board: board, gateway: gateway);
  }
}

// ---------------------------------------------------------------------------
// Phone
// ---------------------------------------------------------------------------

class _PhoneHome extends ConsumerWidget {
  const _PhoneHome({required this.board, required this.gateway});
  final PingBoard board;
  final String? gateway;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final s = board.focused!;
    final st = s.stats;
    final live = board.liveCount > 0;
    final state = hostState(s);
    final v = heroValue(s);
    final others = board.sessions.where((x) => x.id != s.id).toList();
    final label = switch (state) {
      HostState.down => 'No reply',
      HostState.failed => 'Lookup failed',
      HostState.paused => 'Paused',
      HostState.done => 'Done',
      _ => s.host,
    };
    return PulsePage(
      title: 'Ping',
      large: true,
      actions: [
        PulseIconButton(
          icon: live ? PulseIcons.pause : PulseIcons.play,
          tooltip: live ? 'Pause all' : 'Resume all',
          style: PulseIconButtonStyle.neutral,
          visualSize: 48,
          onPressed: () => toggleAll(context, ref),
        ),
        PulseIconButton(
          icon: PulseIcons.tune,
          tooltip: 'Ping settings',
          color: c.onSurface,
          onPressed: () => showPingSettingsSheet(context),
        ),
      ],
      fab: PulseFab(
        label: live ? 'Stop all' : 'Start all',
        icon: live ? PulseIcons.stop : PulseIcons.play,
        onPressed: () => toggleAll(context, ref),
      ),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 112),
      children: [
        Semantics(
          container: true,
          label: 'Hosts',
          child: PulseChipRow(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            children: [
              for (final x in board.sessions)
                PulseChip(
                  label: x.title,
                  selected: x.id == s.id,
                  onTap: () => ref.read(pingBoardProvider.notifier).focus(x.id),
                ),
              PulseChip(label: 'Add host', icon: PulseIcons.plus, onTap: () => showAddHostSheet(context)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Semantics(
            button: true,
            onTapHint: 'Open details',
            child: GestureDetector(
              onTap: () => openPingDetail(context, ref, s),
              child: KeyedSubtree(
                key: ValueKey('hero-${s.id}-${s.running}'),
                child: PulseHeroMetric(
                  value: v.value,
                  unit: v.unit,
                  label: label,
                  size: 220,
                  live: s.running && state != HostState.down,
                  paused: !s.running,
                  semanticLabel: '${s.title} latency ${v.value} ${v.unit ?? ''}, $label',
                ),
              ),
            ),
          ),
        ),
        if (state == HostState.failed) ...[
          const SizedBox(height: 12),
          PulseErrorBanner(
            title: "Can't reach ${s.title}",
            message: s.error,
            onRetry: () => restartHost(context, ref, s),
          ),
        ] else if (state == HostState.down) ...[
          const SizedBox(height: 12),
          PulseErrorBanner(title: noReplyText(s), message: 'The host may be offline or blocking ping.'),
        ],
        const SizedBox(height: 12),
        PulseStatRow(
          stats: [
            PulseStat('Avg', fmtMs(st.avg)),
            PulseStat('Max', fmtMs(st.max)),
            PulseStat(
              'Loss',
              fmtPct(st.lossPct),
              color: st.sent == 0 ? null : (st.lost == 0 ? c.tertiary : context.pulse.latSlow),
            ),
            PulseStat('Jitter', fmtMs(st.jitter)),
          ],
        ),
        if (others.isNotEmpty) ...[
          const PulseSectionLabel('Other hosts', padding: EdgeInsets.fromLTRB(4, 18, 0, 8)),
          PulseSegmentedList(
            children: [for (final x in others) HostListItem(session: x, gateway: gateway)],
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Tablet
// ---------------------------------------------------------------------------

/// "6 hosts live · every 1 s · 0.6% loss overall".
String _boardSummary(PingBoard board) {
  final n = board.sessions.length;
  final live = board.liveCount;
  final intervals = board.sessions.map((s) => s.params.intervalMs).toSet();
  final sent = board.sessions.fold<int>(0, (a, s) => a + s.stats.sent);
  final lost = board.sessions.fold<int>(0, (a, s) => a + s.stats.lost);
  return [
    if (live == 0) '$n ${n == 1 ? 'host' : 'hosts'} · paused' else '$live ${live == 1 ? 'host' : 'hosts'} live',
    if (live > 0 && intervals.length == 1) 'every ${intervalLabel(intervals.first)}',
    if (live > 0 && intervals.length > 1) 'mixed intervals',
    if (live < n && live > 0) '${n - live} paused',
    if (sent > 0) '${fmtPct(lost / sent * 100)} loss overall',
  ].join(' · ');
}

class _TabletHome extends ConsumerWidget {
  const _TabletHome({required this.board, required this.gateway});
  final PingBoard board;
  final String? gateway;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final live = board.liveCount > 0;
    final focused = board.focused;
    return PulsePage(
      title: 'Ping',
      large: true,
      subtitle: _boardSummary(board),
      actions: [
        PulseIconButton(
          icon: PulseIcons.tune,
          tooltip: 'Ping settings',
          onPressed: () => showPingSettingsSheet(context),
        ),
        PulseButton(
          label: live ? 'Pause all' : 'Resume all',
          icon: live ? PulseIcons.pause : PulseIcons.play,
          style: PulseButtonStyle.tonal,
          onPressed: () => toggleAll(context, ref),
        ),
        PulseButton(
          label: 'Add host',
          icon: PulseIcons.plus,
          size: PulseButtonSize.large,
          onPressed: () => showAddHostSheet(context),
        ),
      ],
      body: LayoutBuilder(
        builder: (context, box) {
          const gap = 12.0;
          final pad = context.pagePadding;
          final width = box.maxWidth - pad * 2;
          final cols = width >= 900 ? 3 : (width >= 520 ? 2 : 1);
          final available = box.maxHeight - pad;
          final tile = ((available - gap) / 2).clamp(250.0, 400.0);
          return GridView.builder(
            padding: EdgeInsets.fromLTRB(pad, 0, pad, pad),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols,
              mainAxisSpacing: gap,
              crossAxisSpacing: gap,
              mainAxisExtent: tile,
            ),
            itemCount: board.sessions.length,
            itemBuilder: (context, i) {
              final s = board.sessions[i];
              return PulseEntrance(
                index: i,
                child: HostCard(session: s, gateway: gateway, hero: s.id == focused?.id),
              );
            },
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty
// ---------------------------------------------------------------------------

class _EmptyPing extends ConsumerWidget {
  const _EmptyPing();

  Future<void> _start(BuildContext context, WidgetRef ref, String host, String? name) async {
    final id = await ref
        .read(pingBoardProvider.notifier)
        .start(host, name: name, params: ref.read(pingDraftProvider).params);
    if (id == null && context.mounted) showPingLimit(context);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gateway = ref.watch(gatewayProvider).value;
    final recent = ref.watch(recentTargetsProvider).value ?? const [];
    final compact = context.isCompact;
    return PulsePage(
      title: 'Ping',
      large: true,
      subtitle: compact ? null : 'No hosts yet',
      actions: [
        PulseIconButton(
          icon: PulseIcons.tune,
          tooltip: 'Ping settings',
          color: context.colors.onSurface,
          onPressed: () => showPingSettingsSheet(context),
        ),
        if (!compact)
          PulseButton(
            label: 'Add host',
            icon: PulseIcons.plus,
            size: PulseButtonSize.large,
            onPressed: () => showAddHostSheet(context),
          ),
      ],
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(context.pagePadding, 0, context.pagePadding, 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PulseEmptyState(
                  title: 'Add a host to start pinging',
                  message: 'Pulse pings it every second, shows latency and loss live, and saves each run to History.',
                  icon: PulseIcons.pulse,
                  shape: PulseShape.cookie9,
                  action: Column(
                    children: [
                      PulseButton(
                        label: 'Add host',
                        icon: PulseIcons.plus,
                        size: PulseButtonSize.large,
                        onPressed: () => showAddHostSheet(context),
                      ),
                      const SizedBox(height: 12),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          spacing: 8,
                          children: [
                            PulseChip(label: 'Router', icon: PulseIcons.router, onTap: () => pingRouter(context, ref)),
                            PulseChip(label: '1.1.1.1', onTap: () => _start(context, ref, '1.1.1.1', 'Cloudflare')),
                            PulseChip(label: '8.8.8.8', onTap: () => _start(context, ref, '8.8.8.8', 'Google DNS')),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (recent.isNotEmpty) ...[
                  const PulseSectionLabel('Recent'),
                  PulseSegmentedList(
                    children: [
                      for (final r in recent.take(5))
                        PulseListItem(
                          title: r.name?.isNotEmpty == true ? r.name! : r.host,
                          subtitle: r.name?.isNotEmpty == true ? r.host : 'Tap to ping again',
                          leading: HostBadge(host: r.host, name: r.name, gateway: gateway),
                          trailing: r.avg == null
                              ? null
                              : PulseNumber(fmtMs(r.avg), unit: 'ms', unitScale: .6, style: pulseNumber(18)),
                          onTap: () => _start(context, ref, r.host, r.name),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
