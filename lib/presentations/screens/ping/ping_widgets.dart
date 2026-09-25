import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/format.dart';
import '../../../core/widgets/wire/wire.dart';
import '../../../data/models/ping_models.dart';
import '../../../providers/ping_provider.dart';
import '../../../providers/settings_provider.dart';

/// Hero value for a session: current RTT, "—" for a timeout.
({String value, String? unit}) heroValue(PingSession? s) {
  final last = s?.last;
  if (last == null) return (value: '—', unit: null);
  if (!last.received || last.rttMs == null) return (value: '—', unit: null);
  return (value: fmtMs(last.rttMs), unit: 'ms');
}

List<double?> chartValues(PingSession s, int n) {
  final r = s.replies.length > n ? s.replies.sublist(s.replies.length - n) : s.replies;
  return [for (final x in r) x.received ? x.rttMs : null];
}

String replyLabel(ReplyState s) => switch (s) {
  ReplyState.ok => 'OK',
  ReplyState.slow => 'SLOW',
  ReplyState.timeout => 'TIMEOUT',
  ReplyState.unreachable => 'UNREACH',
};

/// "● LIVE" / "DONE" / "STOPPED" status word.
String sessionStatus(PingSession s) {
  if (s.resolving) return 'RESOLVING';
  if (s.running) return '● LIVE';
  if (s.error != null) return 'UNREACHABLE';
  return s.params.count > 0 && s.stats.sent >= s.params.count ? 'DONE' : 'STOPPED';
}

/// The 5-cell SENT / LOSS / MIN / AVG / MAX strip.
class PingStatStrip extends StatelessWidget {
  const PingStatStrip({super.key, required this.session, this.valueSize = 34});
  final PingSession session;
  final double valueSize;

  @override
  Widget build(BuildContext context) {
    final st = session.stats;
    final lossy = st.lost > 0;
    return WireSplitRow(
      children: [
        WireStat(label: 'Sent', value: fmtCount(st.sent), valueSize: valueSize),
        WireStat(
          label: 'Loss',
          value: fmtPct(st.lossPct),
          valueSize: valueSize,
          tone: lossy ? WireTone.tint : WireTone.plain,
        ),
        WireStat(label: 'Min', value: fmtMs(st.min), valueSize: valueSize),
        WireStat(label: 'Avg', value: fmtMs(st.avg), valueSize: valueSize),
        WireStat(label: 'Max', value: fmtMs(st.max), valueSize: valueSize),
      ],
    );
  }
}

/// Reply log table, newest first. Slow = tint, timeout = muted.
class PingReplyLog extends StatelessWidget {
  const PingReplyLog({super.key, required this.session});
  final PingSession session;

  static const cols = [
    WireCol('Seq', width: 56),
    WireCol('Timestamp', flex: 3),
    WireCol('RTT', flex: 2),
    WireCol('TTL', width: 48),
    WireCol('State', flex: 2),
  ];

  @override
  Widget build(BuildContext context) {
    final w = context.wire;
    final replies = session.replies;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const WireTableHeader(columns: cols),
        Expanded(
          child: replies.isEmpty
              ? Center(
                  child: Text(
                    session.resolving ? 'Resolving ${session.host}…' : 'Waiting for the first reply…',
                    style: WireType.body(13).copyWith(color: w.text3),
                  ),
                )
              : ListView.builder(
                  itemCount: replies.length,
                  itemExtent: 41,
                  itemBuilder: (context, i) {
                    final r = replies[replies.length - 1 - i];
                    final hl = switch (r.state) {
                      ReplyState.slow => WireRowHighlight.tint,
                      ReplyState.timeout || ReplyState.unreachable => WireRowHighlight.muted,
                      ReplyState.ok => WireRowHighlight.none,
                    };
                    final body = WireType.body(14).copyWith(height: 1.2);
                    final bold = WireType.data(14).copyWith(height: 1.2);
                    return WireRow(
                      highlight: hl,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      minHeight: 40,
                      child: WireColumns(
                        columns: cols,
                        cells: [
                          Text(r.seq.toString().padLeft(3, '0'), style: body),
                          Text(fmtTimestamp(r.at), style: body),
                          Text(r.rttMs == null ? '—' : '${fmtMs(r.rttMs)}ms', style: bold),
                          Text(r.ttl?.toString() ?? '—', style: body),
                          Text('${replyLabel(r.state)}${r.v6 ? ' v6' : ''}', style: bold),
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

/// RECENT TARGETS: host + last avg; tapping starts a new live ping.
class PingRecentTargets extends ConsumerWidget {
  const PingRecentTargets({super.key, required this.onPick});
  final void Function(String host, String? name) onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final w = context.wire;
    final recent = ref.watch(recentTargetsProvider).value ?? const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const WireSectionBar('Recent targets'),
        Expanded(
          child: recent.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text('Finished pings land here.', style: WireType.body(13).copyWith(color: w.text3)),
                )
              : ListView(
                  children: [
                    for (final t in recent)
                      WireRow(
                        onTap: () => onPick(t.host, t.name),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(t.host, style: WireType.data(14), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  if (t.name != null)
                                    Text(t.name!, style: WireType.body(11).copyWith(color: w.text2, height: 1.2)),
                                ],
                              ),
                            ),
                            Text(fmtMs(t.avg), style: WireType.stat(24)),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

/// Horizontal strip of every session (shown when more than one exists).
class PingSessionStrip extends ConsumerWidget {
  const PingSessionStrip({super.key, this.height = 44});
  final double height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final w = context.wire;
    final board = ref.watch(pingBoardProvider);
    final notifier = ref.read(pingBoardProvider.notifier);
    final focused = board.focused;
    return Container(
      height: height,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: w.ink, width: kWireBorder),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          WireCell(
            onTap: () => notifier.showBoard(true),
            sides: WireSides.onlyRight,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.center,
            semanticLabel: 'Board',
            child: Text('▦ BOARD ${board.liveCount}/${board.sessions.length}', style: WireType.label(12)),
          ),
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final s in board.sessions)
                  WireCell(
                    selected: s.id == focused?.id,
                    tone: s.unreachable || s.last?.state == ReplyState.slow ? WireTone.tint : WireTone.plain,
                    onTap: () => notifier.focus(s.id),
                    sides: WireSides.onlyRight,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    alignment: Alignment.center,
                    semanticLabel: s.title,
                    child: Row(
                      children: [
                        Text(s.running ? '● ' : '■ ', style: WireType.label(10)),
                        Text(s.title.toUpperCase(), style: WireType.nav(15)),
                        const SizedBox(width: 8),
                        Text(heroValue(s).value, style: WireType.stat(18)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Board: every session as a bordered cell.
class PingBoardGrid extends ConsumerWidget {
  const PingBoardGrid({super.key, this.cellWidth = 300, this.onOpen});
  final double cellWidth;

  /// Called after a cell is focused (mobile pushes the live view).
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(pingBoardProvider.select((b) => b.sessions));
    return LayoutBuilder(
      builder: (context, box) {
        final cols = (box.maxWidth / cellWidth).floor().clamp(1, 6);
        final rows = (sessions.length / cols).ceil();
        return ListView.builder(
          itemCount: rows,
          itemBuilder: (context, r) => IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var c = 0; c < cols; c++)
                  Expanded(
                    child: r * cols + c < sessions.length
                        ? _BoardCell(session: sessions[r * cols + c], right: c < cols - 1, onOpen: onOpen)
                        : WireBox(sides: WireSides(bottom: true, right: c < cols - 1)),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _BoardCell extends ConsumerWidget {
  const _BoardCell({required this.session, required this.right, this.onOpen});
  final PingSession session;
  final bool right;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final w = context.wire;
    final notifier = ref.read(pingBoardProvider.notifier);
    final slow = ref.watch(settingsProvider.select((s) => s.slowThresholdMs));
    final s = session;
    final hero = heroValue(s);
    final tone = s.unreachable || s.last?.state == ReplyState.slow
        ? WireTone.tint
        : s.running
        ? WireTone.plain
        : WireTone.muted;
    return WireCell(
      onTap: () {
        notifier.focus(s.id);
        onOpen?.call();
      },
      tone: tone,
      sides: WireSides(bottom: true, right: right),
      padding: EdgeInsets.zero,
      alignment: Alignment.topLeft,
      semanticLabel: '${s.title} ${hero.value}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.title.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: WireType.title(24),
                      ),
                      Text(
                        s.name == null ? (s.describe ?? '') : s.host,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: WireType.body(12).copyWith(color: w.text2, height: 1.3),
                      ),
                    ],
                  ),
                ),
                Text(sessionStatus(s), style: WireType.label(10)),
                const SizedBox(width: 4),
                _SmallAction(
                  label: s.running ? '■' : '×',
                  tooltip: s.running ? 'Stop' : 'Remove',
                  onTap: () => s.running ? notifier.stop(s.id) : notifier.remove(s.id),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
            child: s.unreachable
                ? Text('UNREACHABLE', style: WireType.display(44, width: 64))
                : WireHeroNumber(value: hero.value, unit: hero.unit, size: 64),
          ),
          SizedBox(
            height: 44,
            child: WireBarChart.latency(
              values: chartValues(s, 30),
              threshold: slow.toDouble(),
              slots: 30,
              gridStep: 22,
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: w.ink, width: kWireHairline),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'LOSS ${fmtPct(s.stats.lossPct)} · AVG ${fmtMs(s.stats.avg)} · MAX ${fmtMs(s.stats.max)} · ${fmtCount(s.stats.sent)} SENT',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: WireType.label(10),
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallAction extends StatelessWidget {
  const _SmallAction({required this.label, required this.onTap, required this.tooltip});
  final String label;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return WirePressable(
      onTap: onTap,
      tooltip: tooltip,
      semanticLabel: tooltip,
      builder: (context, c, s) => Container(
        width: 32,
        height: 32,
        color: c.bg,
        alignment: Alignment.center,
        child: Text(label, style: WireType.data(14).copyWith(color: c.fg)),
      ),
    );
  }
}
