import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/format.dart';
import '../../../core/widgets/wire/wire.dart';
import '../../../core/widgets/wire/wire_page.dart';
import '../../../data/db/app_database.dart';
import '../../../data/models/ping_models.dart';
import '../../../data/models/session_tool.dart';
import '../../../data/repositories/history_repository.dart';
import '../../../providers/history_provider.dart';
import '../../../providers/ping_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../services/export_service.dart';
import '../../navigation/destinations.dart';

/// 03 — History: every finished session, searchable by name or host.
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  late final _search = TextEditingController(text: ref.read(historyFilterProvider).search);

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _export(List<Session> sessions) async {
    final settings = ref.read(settingsProvider);
    final messenger = ScaffoldMessenger.of(context);
    if (sessions.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('Nothing to export.')));
      return;
    }
    try {
      final path = await const ExportService().save(
        fileName: ExportService.stampedName('history', settings.exportFormat),
        content: HistoryRepository.export(sessions, settings.exportFormat),
        settings: settings,
      );
      if (path != null) messenger.showSnackBar(SnackBar(content: Text('Saved $path')));
    } on Object catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessions = ref.watch(historyProvider);
    final list = sessions.value ?? const <Session>[];
    return WireAdaptive(
      mobile: (context) => _mobile(list, sessions.isLoading),
      desktop: (context) => _desktop(list, sessions.isLoading),
    );
  }

  Widget _empty() {
    final filtered = _search.text.isNotEmpty || ref.read(historyFilterProvider).tool != null;
    return WireEmptyState(
      title: filtered ? 'No matches' : 'No history yet',
      message: filtered ? 'Nothing matches that filter.' : 'Run a ping and it lands here.',
      actionLabel: filtered ? null : 'Start ping',
      onAction: filtered ? null : () => context.go(Routes.ping),
      compact: context.isMobileLayout,
    );
  }

  Widget _desktop(List<Session> list, bool loading) {
    final w = context.wire;
    final filter = ref.watch(historyFilterProvider);
    final selectedId = ref.watch(selectedSessionIdProvider);
    final selected = list.where((s) => s.id == selectedId).firstOrNull ?? list.firstOrNull;
    final days = list.isEmpty ? 0 : DateTime.now().difference(list.last.startedAt).inDays + 1;
    final format = ref.watch(settingsProvider.select((s) => s.exportFormat));
    return WireDesktopPage(
      panelWidth: 380,
      topBar: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: WireTopTitle('History', subtitle: '${list.length} SESSIONS · $days DAYS')),
          const WireVRule(),
          SizedBox(
            width: 260,
            child: WireTargetField(
              controller: _search,
              prefix: 'FILTER>',
              hint: 'name, host…',
              fontSize: 13,
              onChanged: (v) => ref.read(historyFilterProvider.notifier).setSearch(v),
            ),
          ),
          const WireVRule(),
          _ToolMenu(selected: filter.tool),
          WireButton(
            label: 'Export ${format.name}',
            variant: WireButtonVariant.inverse,
            bordered: false,
            fontSize: 17,
            height: WireLayout.topBar,
            onPressed: () => _export(list),
          ),
        ],
      ),
      body: list.isEmpty
          ? (loading ? const SizedBox.shrink() : _empty())
          : _Table(sessions: list, selectedId: selected?.id),
      panel: selected == null
          ? Center(
              child: Text('Select a session', style: WireType.body(13).copyWith(color: w.text3)),
            )
          : _Detail(session: selected),
    );
  }

  Widget _mobile(List<Session> list, bool loading) {
    final w = context.wire;
    final filter = ref.watch(historyFilterProvider);
    return WireMobilePage(
      header: WireMobileHeader(
        title: 'History',
        trailing: WirePressable(
          onTap: () => _export(list),
          tone: WireTone.ink,
          semanticLabel: 'Export',
          builder: (context, c, s) => Container(
            color: c.bg,
            height: WireLayout.mobileHeader,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text('EXPORT', style: WireType.label(12).copyWith(color: s.isEmpty ? w.signal : c.fg)),
          ),
        ),
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
            child: WireSegmented<SessionTool?>(
              bordered: false,
              height: WireLayout.minHit,
              textStyle: WireType.label(11),
              options: const [
                (null, 'ALL'),
                (SessionTool.ping, 'PING'),
                (SessionTool.trace, 'TRACE'),
                (SessionTool.speed, 'SPEED'),
              ],
              selected: filter.tool,
              onChanged: (t) => ref.read(historyFilterProvider.notifier).setTool(t),
            ),
          ),
          Container(
            height: 46,
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: w.ink, width: kWireBorder),
              ),
            ),
            child: WireTargetField(
              controller: _search,
              prefix: 'FILTER>',
              hint: 'name, host…',
              fontSize: 14,
              onChanged: (v) => ref.read(historyFilterProvider.notifier).setSearch(v),
            ),
          ),
          Expanded(
            child: list.isEmpty
                ? (loading ? const SizedBox.shrink() : _empty())
                : ListView.builder(
                    itemCount: list.length,
                    itemBuilder: (context, i) {
                      final s = list[i];
                      return WireRow(
                        onTap: () => _showMobileDetail(context, s),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    s.label == null ? s.target : '${s.label!.toUpperCase()} · ${s.target}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: WireType.data(14),
                                  ),
                                  Text(
                                    '${fmtWhen(s.startedAt)} · ${s.tool.toUpperCase()} · LOSS ${fmtPct(s.lossPct)}',
                                    style: WireType.body(11).copyWith(color: w.text2, height: 1.3),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(_avgText(s), style: WireType.stat(24)),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showMobileDetail(BuildContext context, Session s) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      sheetAnimationStyle: kWireSheetAnimation,
      useSafeArea: true,
      builder: (context) => ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
        child: _Detail(session: s, onDone: () => Navigator.of(context).pop()),
      ),
    );
  }
}

String _avgText(Session s) {
  if (s.tool == SessionTool.ping.name || s.tool == SessionTool.trace.name) return fmtMs(s.avgMs);
  final summary = s.summary.split(' · ').first;
  return summary.isEmpty ? '—' : summary;
}

class _ToolMenu extends ConsumerWidget {
  const _ToolMenu({required this.selected});
  final SessionTool? selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<SessionTool?>(
      tooltip: 'Filter by tool',
      position: PopupMenuPosition.under,
      onSelected: (t) => ref.read(historyFilterProvider.notifier).setTool(t),
      itemBuilder: (context) => [
        const PopupMenuItem(value: null, child: Text('ALL TOOLS')),
        for (final t in SessionTool.values) PopupMenuItem(value: t, child: Text(t.label)),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border(
            right: BorderSide(color: context.wire.ink, width: kWireBorder),
          ),
        ),
        child: Text('${selected?.label ?? 'ALL TOOLS'} ▾', style: WireType.data(13)),
      ),
    );
  }
}

class _Table extends ConsumerWidget {
  const _Table({required this.sessions, required this.selectedId});
  final List<Session> sessions;
  final int? selectedId;

  static const cols = [
    WireCol('When', width: 110),
    WireCol('Target', flex: 3),
    WireCol('Tool', width: 64),
    WireCol('Avg', width: 80),
    WireCol('Loss', width: 56),
    WireCol('Trend', width: 110),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final w = context.wire;
    final slow = ref.watch(settingsProvider.select((s) => s.slowThresholdMs)).toDouble();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const WireTableHeader(columns: cols, gap: 10),
        Expanded(
          child: ListView.builder(
            itemCount: sessions.length,
            itemBuilder: (context, i) {
              final s = sessions[i];
              final trend = HistoryRepository.trendOf(s);
              return WireRow(
                selected: s.id == selectedId,
                onTap: () => ref.read(selectedSessionIdProvider.notifier).select(s.id),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
                child: WireColumns(
                  columns: cols,
                  gap: 10,
                  cells: [
                    Text(fmtWhen(s.startedAt), style: WireType.body(13).copyWith(color: w.text2, height: 1.2)),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (s.label != null)
                          Text(
                            s.label!.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: WireType.nav(15),
                          ),
                        Text(s.target, maxLines: 1, overflow: TextOverflow.ellipsis, style: WireType.data(13)),
                      ],
                    ),
                    Text(s.tool.toUpperCase(), style: WireType.body(13).copyWith(height: 1.2)),
                    Text(_avgText(s), maxLines: 1, style: WireType.data(13)),
                    Text(fmtPct(s.lossPct), style: WireType.body(13).copyWith(height: 1.2)),
                    WireSparkline(values: trend, threshold: s.tool == SessionTool.ping.name ? slow : null),
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

class _Detail extends ConsumerWidget {
  const _Detail({required this.session, this.onDone});
  final Session session;
  final VoidCallback? onDone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final w = context.wire;
    final s = session;
    final payload = HistoryRepository.payloadOf(s);
    final stats = payload['stats'] is Map ? PingStats.fromJson((payload['stats'] as Map).cast()) : null;
    final replies = payload['replies'] is List
        ? [for (final r in (payload['replies'] as List).cast<Map>()) PingReply.fromJson(r.cast())]
        : const <PingReply>[];
    final slow = ref.watch(settingsProvider.select((x) => x.slowThresholdMs)).toDouble();
    final cells = stats == null
        ? <(String, String)>[('Result', s.summary.isEmpty ? '—' : s.summary), ('Tool', s.tool.toUpperCase())]
        : <(String, String)>[
            ('Sent', fmtCount(stats.sent)),
            ('Lost', fmtCount(stats.lost)),
            ('Avg', fmtMs(stats.avg)),
            ('Jitter', fmtMs(stats.jitter)),
            ('Min', fmtMs(stats.min)),
            ('Max', fmtMs(stats.max)),
          ];

    Future<void> rerun() async {
      if (s.tool == SessionTool.ping.name) {
        final params = payload['params'] is Map ? PingParams.fromJson((payload['params'] as Map).cast()) : null;
        await ref.read(pingBoardProvider.notifier).start(s.target, name: s.label, params: params);
        onDone?.call();
        if (context.mounted) context.go(Routes.ping);
        return;
      }
      final route = switch (SessionTool.byName(s.tool)) {
        SessionTool.trace => Routes.traceroute,
        SessionTool.ports => Routes.ports,
        SessionTool.speed => Routes.speed,
        SessionTool.loss => Routes.loss,
        SessionTool.lan => Routes.lan,
        SessionTool.geo => Routes.geo,
        _ => Routes.ping,
      };
      onDone?.call();
      if (context.mounted) context.go('$route?target=${Uri.encodeComponent(s.target)}');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: w.ink, width: kWireBorder),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('SESSION · ${fmtWhen(s.startedAt)}', style: WireType.label()),
              const SizedBox(height: 4),
              Text(
                (s.label ?? s.target).toUpperCase(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: WireType.title(30),
              ),
              if (s.label != null) Text(s.target, style: WireType.data(13).copyWith(color: w.text2)),
            ],
          ),
        ),
        for (var i = 0; i < cells.length; i += 2)
          Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: w.ink, width: kWireBorder),
              ),
            ),
            child: WireSplitRow(
              children: [
                WireStat(
                  label: cells[i].$1,
                  value: cells[i].$2,
                  valueSize: 30,
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                ),
                if (i + 1 < cells.length)
                  WireStat(
                    label: cells[i + 1].$1,
                    value: cells[i + 1].$2,
                    valueSize: 30,
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                  )
                else
                  const SizedBox.shrink(),
              ],
            ),
          ),
        if (replies.isNotEmpty)
          Container(
            height: 120,
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: w.ink, width: kWireBorder),
              ),
            ),
            child: WireBarChart.latency(
              values: [
                for (final r in replies.length > 60 ? replies.sublist(replies.length - 60) : replies)
                  r.received ? r.rttMs : null,
              ],
              threshold: slow,
              gridStep: 30,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            ),
          ),
        const Spacer(),
        Container(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: w.ink, width: kWireBorder),
            ),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: WireButton(
                    label: 'Re-run',
                    variant: WireButtonVariant.primary,
                    bordered: false,
                    sides: WireSides.onlyRight,
                    fontSize: 16,
                    height: 52,
                    onPressed: rerun,
                  ),
                ),
                Expanded(
                  child: WireButton(
                    label: '.TXT',
                    bordered: false,
                    sides: WireSides.onlyRight,
                    fontSize: 16,
                    height: 52,
                    onPressed: () async {
                      final settings = ref.read(settingsProvider);
                      final messenger = ScaffoldMessenger.of(context);
                      final name = (s.label ?? s.target).replaceAll(RegExp(r'[^A-Za-z0-9.-]+'), '_');
                      final path = await const ExportService().save(
                        fileName: 'pulse-${s.tool}-$name-${s.id}.txt',
                        content: HistoryRepository.report(s),
                        settings: settings,
                      );
                      if (path != null) messenger.showSnackBar(SnackBar(content: Text('Saved $path')));
                    },
                  ),
                ),
                Expanded(
                  child: WireButton(
                    label: 'Delete',
                    bordered: false,
                    fontSize: 16,
                    height: 52,
                    onPressed: () async {
                      await ref.read(historyRepositoryProvider).delete(s.id);
                      ref.read(selectedSessionIdProvider.notifier).select(null);
                      HapticFeedback.lightImpact();
                      onDone?.call();
                    },
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
