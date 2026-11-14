import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/format.dart';
import '../../../core/share/pulse_share.dart';
import '../../../core/widgets/pulse/pulse.dart';
import '../../../data/models/app_settings.dart';
import '../../../providers/ping_provider.dart';
import '../../navigation/destinations.dart';
import '../../navigation/tools_catalog.dart';
import 'ping_configure.dart';
import 'ping_widgets.dart';

final _hm = DateFormat('HH:mm');

/// 03 Ping detail for one host (`/ping/host?id=<session id>`).
///
/// * Phone: hero 176 with verdict, "Last 30 pings", stats, setting chips that
///   open option sheets, Stop / Resume and share, then the reply log.
/// * Tablet (expanded): Hosts pane (340) next to the detail: hero 260, pills,
///   2 x 2 stats, "Last 60 pings", reply log, setting chips and Stop.
class PingDetailScreen extends ConsumerWidget {
  const PingDetailScreen({super.key, this.id});
  final String? id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final board = ref.watch(pingBoardProvider);
    final gateway = ref.watch(gatewayProvider).value;
    PingSession? s;
    for (final x in board.sessions) {
      if (x.id == id) s = x;
    }
    if (s == null && board.focused != null) {
      // Restarted elsewhere (new id): follow the focused host.
      s = board.focused;
      final fix = '${Routes.pingDetail}?id=${Uri.encodeQueryComponent(s!.id)}';
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) GoRouter.maybeOf(context)?.go(fix);
      });
    }
    if (s == null) {
      return PulsePage(
        title: 'Ping',
        backTo: Routes.ping,
        showBack: true,
        body: Center(
          child: PulseEmptyState(
            title: 'This host is gone',
            message: 'It was removed from the board. Its runs are in History.',
            icon: PulseIcons.pulse,
            shape: PulseShape.cookie9,
            action: PulseButton(label: 'Back to Ping', onPressed: () => context.go(Routes.ping)),
          ),
        ),
      );
    }
    if (context.isCompact) return _PhoneDetail(session: s);
    final detail = _TabletDetail(session: s, showBack: !context.isExpanded);
    if (!context.isExpanded) return detail;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _HostsPane(board: board, selectedId: s.id, gateway: gateway),
        Expanded(child: detail),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Shared pieces
// ---------------------------------------------------------------------------

String _hostLine(PingSession s) => s.name?.isNotEmpty == true ? s.host : (s.describe ?? 'Ping');

/// This host's run as a shareable card.
ShareableResult pingShareResult(PingSession s) {
  final st = s.stats;
  return kPingTool.shareResult(
    headline: fmtMs(st.avg),
    unit: 'ms',
    caption: 'Average ping',
    target: s.name?.isNotEmpty == true ? '${s.name} · ${s.host}' : s.host,
    at: s.startedAt,
    stats: [
      ShareStat('Loss', fmtPct(st.lossPct)),
      ShareStat('Min', fmtMs(st.min), unit: 'ms'),
      ShareStat('Max', fmtMs(st.max), unit: 'ms'),
      ShareStat('Jitter', fmtMs(st.jitter), unit: 'ms'),
      ShareStat('Replies', '${st.received}/${st.sent}'),
    ],
  );
}

Future<void> _toggle(BuildContext context, WidgetRef ref, PingSession s) async {
  if (s.running) {
    await ref.read(pingBoardProvider.notifier).stop(s.id);
  } else {
    await restartHost(context, ref, s, followDetail: true);
  }
}

({String label, PulseIcons icon}) _toggleLabel(PingSession s) {
  if (s.running) return (label: 'Stop', icon: PulseIcons.stop);
  if (hostState(s) == HostState.done || s.error != null) return (label: 'Run again', icon: PulseIcons.refresh);
  return (label: 'Resume', icon: PulseIcons.play);
}

enum _More { edit, rename, save, copy, trace, ports, loss, geo, restart, remove }

class _MoreMenu extends ConsumerWidget {
  const _MoreMenu({required this.session});
  final PingSession session;

  Future<void> _rename(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(text: session.name ?? '');
    final n = ref.read(pingBoardProvider.notifier);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename'),
        content: SizedBox(
          width: 360,
          child: PulseTargetField(
            controller: controller,
            hint: 'Name, e.g. Office PC',
            icon: PulseIcons.pin,
            keyboardType: TextInputType.text,
            autofocus: true,
            onSubmitted: (v) => Navigator.of(context).pop(v),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(controller.text), child: const Text('Save')),
        ],
      ),
    );
    controller.dispose();
    if (name != null) n.rename(session.id, name);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = session;
    final target = Uri.encodeQueryComponent(s.host);
    return PopupMenuButton<_More>(
      tooltip: 'More',
      icon: PulseIcon(PulseIcons.more, size: 22, color: context.colors.onSurfaceVariant),
      onSelected: (v) async {
        final n = ref.read(pingBoardProvider.notifier);
        switch (v) {
          case _More.edit:
            showAddHostSheet(context, edit: s);
          case _More.rename:
            _rename(context, ref);
          case _More.save:
            showSavedTargetDialog(context, host: s.host, name: s.name ?? '');
          case _More.copy:
            Clipboard.setData(ClipboardData(text: s.host));
            ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text('Copied ${s.host}')));
          case _More.trace:
            context.go('${Routes.traceroute}?target=$target');
          case _More.ports:
            context.go('${Routes.ports}?target=$target');
          case _More.loss:
            context.go('${Routes.loss}?target=$target');
          case _More.geo:
            context.go('${Routes.geo}?target=$target');
          case _More.restart:
            restartHost(context, ref, s, followDetail: true);
          case _More.remove:
            context.go(Routes.ping);
            await n.remove(s.id);
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(value: _More.edit, child: Text('Edit host')),
        PopupMenuItem(value: _More.rename, child: Text('Rename')),
        PopupMenuItem(value: _More.save, child: Text('Save as target')),
        PopupMenuItem(value: _More.copy, child: Text('Copy address')),
        PopupMenuDivider(),
        PopupMenuItem(value: _More.trace, child: Text('Traceroute')),
        PopupMenuItem(value: _More.ports, child: Text('Scan ports')),
        PopupMenuItem(value: _More.loss, child: Text('Packet loss test')),
        PopupMenuItem(value: _More.geo, child: Text('Geo IP')),
        PopupMenuDivider(),
        PopupMenuItem(value: _More.restart, child: Text('Restart')),
        PopupMenuItem(value: _More.remove, child: Text('Remove host')),
      ],
    );
  }
}

/// Setting chips: interval · size · timeout (· count · IP) · Alert.
class _SettingChips extends ConsumerWidget {
  const _SettingChips({required this.session, this.long = false});
  final PingSession session;
  final bool long;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = session.params;
    final alert = ref.watch(hostHasAlertProvider(session.host));
    void open(PingOption o) => showHostOptionsSheet(context, session, only: o);
    return PulseChipRow(
      children: [
        PulseChip(
          label: long ? 'Interval ${intervalLabel(p.intervalMs)}' : intervalLabel(p.intervalMs),
          icon: PulseIcons.timer,
          small: !long,
          onTap: () => open(PingOption.interval),
        ),
        PulseChip(
          label: long ? 'Size ${p.packetSize} B' : '${p.packetSize} B',
          small: !long,
          onTap: () => open(PingOption.size),
        ),
        PulseChip(label: 'Timeout ${p.timeoutSec} s', small: !long, onTap: () => open(PingOption.timeout)),
        if (p.count > 0) PulseChip(label: '${p.count} pings', small: !long, onTap: () => open(PingOption.count)),
        if (p.ipVersion != IpVersionPref.auto)
          PulseChip(label: ipVersionLabel(p.ipVersion), small: !long, onTap: () => open(PingOption.ipVersion)),
        PulseChip(
          label: long ? (alert ? 'Alert on' : 'Alert on loss') : 'Alert',
          icon: PulseIcons.bell,
          selected: alert,
          showCheck: false,
          small: !long,
          onTap: () => showHostAlertSheet(context, session),
        ),
      ],
    );
  }
}

/// "Last N pings" card: pill bars with a dashed average line.
class _PingsChart extends StatelessWidget {
  const _PingsChart({required this.session, required this.count, required this.height, this.wide = false});
  final PingSession session;
  final int count;
  final double height;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final values = chartValues(session, count);
    final present = values.whereType<double>().toList();
    final avg = present.isEmpty ? null : present.reduce((a, b) => a + b) / present.length;
    final peak = present.isEmpty ? 0.0 : present.reduce(math.max);
    final top = math.max(100.0, peak * 1.1);
    final lost = values.length - present.length;
    final span = Duration(milliseconds: values.length * session.params.intervalMs);
    final label = context.type.labelMedium!.copyWith(color: c.onSurfaceVariant);
    return PulseCard(
      padding: wide ? const EdgeInsets.fromLTRB(20, 16, 20, 16) : const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Last $count pings',
                  style: context.type.titleMedium!.copyWith(fontSize: wide ? 17 : 18, fontWeight: FontWeight.w700),
                ),
              ),
              if (wide)
                const LatencyLegend()
              else if (avg != null)
                Text('avg ${fmtMs(avg)} ms', style: label.copyWith(fontSize: 14)),
            ],
          ),
          SizedBox(height: wide ? 14 : 12),
          if (values.isEmpty)
            SizedBox(
              height: height,
              child: Center(
                child: Text(
                  session.resolving ? 'Resolving ${session.host}…' : 'Waiting for the first reply…',
                  style: context.type.bodyMedium!.copyWith(color: c.onSurfaceVariant),
                ),
              ),
            )
          else
            PulseBars(
              values: values,
              height: height,
              max: top,
              barWidth: wide ? 8 : 7,
              gap: wide ? 5 : 4,
              fill: values.length >= count * .8,
              average: avg,
              semanticLabel:
                  'Last ${values.length} pings, average ${fmtMs(avg)} ms, max ${fmtMs(peak)} ms'
                  '${lost > 0 ? ', $lost lost' : ''}',
            ),
          if (!wide) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Text(values.isEmpty ? '' : '${fmtSpan(span)} ago', style: label.copyWith(fontSize: 14)),
                const Spacer(),
                Text('now', style: label.copyWith(fontSize: 14)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Reply log section: newest 10 rows, "Show all" opens the full log.
class _Replies extends StatelessWidget {
  const _Replies({required this.session});
  final PingSession session;

  @override
  Widget build(BuildContext context) {
    final n = session.replies.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PulseSectionLabel(
          n == 0 ? 'Replies' : 'Replies · $n',
          padding: const EdgeInsets.fromLTRB(4, 20, 0, 8),
          trailing: n > 10
              ? PulseButton(
                  label: 'Show all',
                  style: PulseButtonStyle.text,
                  size: PulseButtonSize.small,
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    useSafeArea: true,
                    useRootNavigator: true,
                    builder: (context) => _ReplyLogSheet(id: session.id),
                  ),
                )
              : null,
        ),
        ReplyLogList(session: session, limit: 10),
      ],
    );
  }
}

class _ReplyLogSheet extends ConsumerWidget {
  const _ReplyLogSheet({required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(pingBoardProvider.select((b) => b.sessions.where((x) => x.id == id).firstOrNull));
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * .85,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text('Replies · ${s?.title ?? ''}', style: context.type.headlineSmall),
          ),
          Expanded(
            child: s == null
                ? const SizedBox()
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    children: [ReplyLogList(session: s)],
                  ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Phone
// ---------------------------------------------------------------------------

class _PhoneDetail extends ConsumerWidget {
  const _PhoneDetail({required this.session});
  final PingSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final s = session;
    final st = s.stats;
    final state = hostState(s);
    final v = heroValue(s);
    final p = s.params;
    final sup = context.type.bodyMedium!.copyWith(color: c.onSurfaceVariant, fontSize: 15);
    final toggle = _toggleLabel(s);
    return PulsePage(
      title: s.title,
      subtitle: _hostLine(s),
      backTo: Routes.ping,
      actions: [
        PulseIconButton(
          icon: PulseIcons.tune,
          tooltip: 'Ping options',
          color: c.onSurface,
          onPressed: () => showHostOptionsSheet(context, s),
        ),
        _MoreMenu(session: s),
      ],
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        Row(
          children: [
            KeyedSubtree(
              key: ValueKey('hero-${s.id}-${s.running}'),
              child: PulseHeroMetric(
                value: v.value,
                unit: v.unit,
                label: switch (state) {
                  HostState.down => 'No reply',
                  HostState.paused => 'Paused',
                  HostState.done => 'Done',
                  HostState.failed => 'Failed',
                  _ => 'Live',
                },
                size: 176,
                blob: false,
                live: s.running && state != HostState.down,
                paused: !s.running,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (state == HostState.paused) const PulsePill('Paused', tone: PulsePillTone.outline, height: 32),
                      if (state == HostState.done) const PulsePill('Done', tone: PulsePillTone.outline, height: 32),
                      HostVerdictPill(session: s),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Every ${intervalLabel(p.intervalMs)} · ${p.packetSize} bytes\nTimeout ${p.timeoutSec} s',
                    style: sup,
                  ),
                  const SizedBox(height: 8),
                  Text('Started ${_hm.format(s.startedAt)} · ${fmtCount(st.sent)} sent', style: sup),
                ],
              ),
            ),
          ],
        ),
        if (state == HostState.failed || state == HostState.down || st.lost > 0) ...[
          const SizedBox(height: 12),
          if (state == HostState.failed)
            PulseErrorBanner(
              title: "Can't reach ${s.title}",
              message: s.error,
              onRetry: () => restartHost(context, ref, s, followDetail: true),
            )
          else if (state == HostState.down)
            PulseErrorBanner(title: noReplyText(s), message: 'The host may be offline or blocking ping.')
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(verdictText(s), style: context.type.bodyMedium!.copyWith(color: c.onSurfaceVariant)),
            ),
        ],
        const SizedBox(height: 16),
        _PingsChart(session: s, count: 30, height: 64),
        const SizedBox(height: 12),
        PulseStatRow(
          stats: [
            PulseStat('Avg', fmtMs(st.avg)),
            PulseStat(
              'Loss',
              fmtPct(st.lossPct),
              color: st.sent == 0 ? null : (st.lost == 0 ? c.tertiary : context.pulse.latSlow),
            ),
            PulseStat('Max', fmtMs(st.max), color: st.max == null ? null : context.pulse.latencyColor(st.max)),
            PulseStat('Jitter', fmtMs(st.jitter)),
          ],
        ),
        const SizedBox(height: 6),
        _SettingChips(session: s),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: PulseButton(
                label: toggle.label,
                icon: toggle.icon,
                size: PulseButtonSize.large,
                expand: true,
                onPressed: () => _toggle(context, ref, s),
              ),
            ),
            const SizedBox(width: 8),
            PulseIconButton(
              icon: PulseIcons.share,
              tooltip: 'Share result',
              style: PulseIconButtonStyle.tonal,
              visualSize: 56,
              onPressed: () => showShareResult(context, pingShareResult(s)),
            ),
          ],
        ),
        _Replies(session: s),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Tablet
// ---------------------------------------------------------------------------

class _HostsPane extends ConsumerWidget {
  const _HostsPane({required this.board, required this.selectedId, required this.gateway});
  final PingBoard board;
  final String selectedId;
  final String? gateway;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final live = board.liveCount > 0;
    return PulsePane(
      width: 340,
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PulsePaneHeader(
            title: 'Hosts',
            actions: [
              PulseIconButton(
                icon: live ? PulseIcons.pause : PulseIcons.play,
                tooltip: live ? 'Pause all' : 'Resume all',
                style: PulseIconButtonStyle.neutral,
                visualSize: 48,
                onPressed: () => toggleAll(context, ref),
              ),
            ],
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                PulseSegmentedList(
                  children: [
                    for (final s in board.sessions)
                      HostListItem(
                        session: s,
                        gateway: gateway,
                        selected: s.id == selectedId,
                        color: context.colors.surfaceContainerHigh,
                        minHeight: 62,
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          PulseButton(
            label: 'Add host',
            icon: PulseIcons.plus,
            size: PulseButtonSize.large,
            expand: true,
            onPressed: () => showAddHostSheet(context),
          ),
        ],
      ),
    );
  }
}

class _TabletDetail extends ConsumerWidget {
  const _TabletDetail({required this.session, required this.showBack});
  final PingSession session;
  final bool showBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final s = session;
    final st = s.stats;
    final state = hostState(s);
    final v = heroValue(s);
    final toggle = _toggleLabel(s);
    final pad = context.pagePadding;
    final hero = KeyedSubtree(
      key: ValueKey('hero-${s.id}-${s.running}'),
      child: PulseHeroMetric(
        value: v.value,
        unit: v.unit,
        label: switch (state) {
          HostState.down => 'No reply',
          HostState.paused => 'Paused',
          HostState.done => 'Done',
          HostState.failed => 'Failed',
          _ => 'Live',
        },
        size: 260,
        live: s.running && state != HostState.down,
        paused: !s.running,
      ),
    );
    final side = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (state == HostState.paused) const PulsePill('Paused', tone: PulsePillTone.outline, height: 32),
            if (state == HostState.done) const PulsePill('Done', tone: PulsePillTone.outline, height: 32),
            HostVerdictPill(session: s),
            if (st.jitter != null) PulsePill('Jitter ${fmtMs(st.jitter)} ms', tone: PulsePillTone.lavender, height: 32),
            PulsePill(paramsShort(s.params), height: 32),
          ],
        ),
        const SizedBox(height: 14),
        _StatGrid(session: s),
        if (state != HostState.live || st.lost > 0) ...[
          const SizedBox(height: 10),
          Text(verdictText(s), style: context.type.bodyMedium!.copyWith(color: c.onSurfaceVariant)),
        ],
      ],
    );
    return PulsePage(
      title: s.title,
      titleWidget: Text(s.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.type.headlineLarge),
      subtitle:
          '${s.name?.isNotEmpty == true ? s.host : (s.describe ?? s.host)} · started ${_hm.format(s.startedAt)} · '
          '${fmtCount(st.sent)} sent',
      backTo: Routes.ping,
      showBack: showBack,
      actions: [
        PulseIconButton(
          icon: PulseIcons.tune,
          tooltip: 'Ping options',
          onPressed: () => showHostOptionsSheet(context, s),
        ),
        PulseIconButton(
          icon: PulseIcons.share,
          tooltip: 'Share result',
          onPressed: () => showShareResult(context, pingShareResult(s)),
        ),
        _MoreMenu(session: s),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(pad, 0, pad, 16),
              children: [
                LayoutBuilder(
                  builder: (context, box) => box.maxWidth >= 640
                      ? Row(
                          children: [
                            hero,
                            const SizedBox(width: 28),
                            Expanded(child: side),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Center(child: hero),
                            const SizedBox(height: 16),
                            side,
                          ],
                        ),
                ),
                if (state == HostState.failed) ...[
                  const SizedBox(height: 12),
                  PulseErrorBanner(
                    title: "Can't reach ${s.title}",
                    message: s.error,
                    onRetry: () => restartHost(context, ref, s, followDetail: true),
                  ),
                ],
                const SizedBox(height: 16),
                PulseEntrance(index: 2, child: _PingsChart(session: s, count: 60, height: 150, wide: true)),
                _Replies(session: s),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(pad, 8, pad, 16),
            child: Row(
              children: [
                Expanded(child: _SettingChips(session: s, long: true)),
                const SizedBox(width: 12),
                PulseButton(
                  label: toggle.label,
                  icon: toggle.icon,
                  size: PulseButtonSize.large,
                  onPressed: () => _toggle(context, ref, s),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 2 x 2 stats: Average, Loss, Max, Min (28 px values).
class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.session});
  final PingSession session;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final st = session.stats;
    final tiles = <(String, String, String?, Color?)>[
      ('Average', fmtMs(st.avg), st.avg == null ? null : 'ms', null),
      ('Loss', fmtPct(st.lossPct), null, st.sent == 0 ? null : (st.lost == 0 ? c.tertiary : context.pulse.latSlow)),
      ('Max', fmtMs(st.max), st.max == null ? null : 'ms', st.max == null ? null : context.pulse.latencyColor(st.max)),
      ('Min', fmtMs(st.min), st.min == null ? null : 'ms', null),
    ];
    const radii = [
      BorderRadius.only(
        topLeft: Radius.circular(22),
        topRight: Radius.circular(6),
        bottomLeft: Radius.circular(6),
        bottomRight: Radius.circular(6),
      ),
      BorderRadius.only(
        topLeft: Radius.circular(6),
        topRight: Radius.circular(22),
        bottomLeft: Radius.circular(6),
        bottomRight: Radius.circular(6),
      ),
      BorderRadius.only(
        topLeft: Radius.circular(6),
        topRight: Radius.circular(6),
        bottomLeft: Radius.circular(22),
        bottomRight: Radius.circular(6),
      ),
      BorderRadius.only(
        topLeft: Radius.circular(6),
        topRight: Radius.circular(6),
        bottomLeft: Radius.circular(6),
        bottomRight: Radius.circular(22),
      ),
    ];
    Widget tile(int i) {
      final t = tiles[i];
      return Semantics(
        label: '${t.$1} ${t.$2} ${t.$3 ?? ''}',
        excludeSemantics: true,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(color: c.surfaceContainerHigh, borderRadius: radii[i]),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t.$1, style: context.type.bodySmall!.copyWith(color: c.onSurfaceVariant)),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: PulseNumber(
                  t.$2,
                  unit: t.$3,
                  live: true,
                  unitScale: 1,
                  unitGap: 6,
                  style: pulseNumber(28),
                  color: t.$4,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: tile(0)),
            const SizedBox(width: 6),
            Expanded(child: tile(1)),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(child: tile(2)),
            const SizedBox(width: 6),
            Expanded(child: tile(3)),
          ],
        ),
      ],
    );
  }
}
