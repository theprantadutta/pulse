import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/widgets/pulse/pulse.dart';
import '../../../data/db/app_database.dart';
import '../../../data/models/app_settings.dart';
import '../../../data/models/session_tool.dart';
import '../../../data/repositories/history_repository.dart';
import '../../../providers/history_provider.dart';
import '../../../providers/ping_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../services/export_service.dart';
import '../../navigation/destinations.dart';
import 'run_detail.dart';
import 'run_info.dart';

/// Type chips: All · Ping · Trace · Speed · Ports · LAN · Geo · Loss.
const _chips = <(SessionTool?, String)>[
  (null, 'All'),
  (SessionTool.ping, 'Ping'),
  (SessionTool.trace, 'Trace'),
  (SessionTool.speed, 'Speed'),
  (SessionTool.ports, 'Ports'),
  (SessionTool.lan, 'LAN'),
  (SessionTool.geo, 'Geo'),
  (SessionTool.loss, 'Loss'),
];

/// 13 History: every finished run, filterable by type and name / host.
///
/// * Phone: large app bar with search + export, type chips, day headers and a
///   segmented list; a row pushes the run detail.
/// * Expanded (>= 840): list-detail. A 420 dp pane (title, export, filter
///   field, chips, list) next to the selected run.
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  late final _search = TextEditingController(text: ref.read(historyFilterProvider).search);
  late bool _searchOpen = _search.text.isNotEmpty;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool get _filtered {
    final f = ref.read(historyFilterProvider);
    return f.tool != null || f.search.trim().isNotEmpty;
  }

  void _clearFilters() {
    _search.clear();
    ref.read(historyFilterProvider.notifier)
      ..setSearch('')
      ..setTool(null);
    setState(() => _searchOpen = false);
  }

  // ---------------------------------------------------------------------------
  // Export
  // ---------------------------------------------------------------------------

  Future<void> _openExport(List<Session> filtered) async {
    final choice = await showModalBottomSheet<(ExportFormat, bool)>(
      useRootNavigator: true,
      context: context,
      showDragHandle: true,
      backgroundColor: context.colors.surfaceContainerLow,
      builder: (context) => _ExportSheet(
        initial: ref.read(settingsProvider).exportFormat,
        filteredCount: _filtered ? filtered.length : null,
      ),
    );
    if (choice == null) return;
    final (format, all) = choice;
    final sessions = all ? await ref.read(historyRepositoryProvider).watch().first : filtered;
    await _export(sessions, format, all ? 'history' : 'history-filtered');
  }

  Future<void> _export(List<Session> sessions, ExportFormat format, String base) async {
    final settings = ref.read(settingsProvider);
    final messenger = ScaffoldMessenger.of(context);
    if (sessions.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('Nothing to export yet')));
      return;
    }
    try {
      final path = await const ExportService().save(
        fileName: ExportService.stampedName(base, format),
        content: HistoryRepository.export(sessions, format),
        settings: settings,
      );
      if (path != null) messenger.showSnackBar(SnackBar(content: Text('Saved $path')));
    } on Object catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(historyProvider);
    final list = async.value ?? const <Session>[];
    if (context.isExpanded) return _tablet(async, list);
    return _phone(async, list);
  }

  void _openRun(Session s) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => Scaffold(
          backgroundColor: context.colors.surface,
          body: SafeArea(
            bottom: false,
            child: RunDetail(session: s, compact: true, onClose: () => Navigator.of(context).maybePop()),
          ),
        ),
      ),
    );
  }

  Widget _chipRow({required bool small, EdgeInsetsGeometry padding = EdgeInsets.zero}) {
    final tool = ref.watch(historyFilterProvider.select((f) => f.tool));
    return PulseChipRow(
      padding: padding,
      children: [
        for (final (t, label) in _chips)
          PulseChip(
            label: label,
            small: small,
            selected: tool == t,
            onTap: () => ref.read(historyFilterProvider.notifier).setTool(t),
          ),
      ],
    );
  }

  Widget _phone(AsyncValue<List<Session>> async, List<Session> list) {
    final pad = context.pagePadding;
    return PulsePage(
      title: 'History',
      large: true,
      actions: [
        PulseIconButton(
          icon: _searchOpen ? PulseIcons.x : PulseIcons.search,
          tooltip: _searchOpen ? 'Close search' : 'Search',
          onPressed: () {
            if (_searchOpen) {
              _search.clear();
              ref.read(historyFilterProvider.notifier).setSearch('');
            }
            setState(() => _searchOpen = !_searchOpen);
          },
        ),
        PulseIconButton(icon: PulseIcons.export, tooltip: 'Export', onPressed: () => _openExport(list)),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_searchOpen)
            Padding(
              padding: EdgeInsets.fromLTRB(pad, 4, pad, 4),
              child: PulseTargetField(
                controller: _search,
                hint: 'Filter by name or host',
                keyboardType: TextInputType.text,
                autofocus: _search.text.isEmpty,
                onChanged: (v) => ref.read(historyFilterProvider.notifier).setSearch(v),
              ),
            ),
          _chipRow(small: false, padding: EdgeInsets.fromLTRB(pad, 0, pad, 0)),
          Expanded(
            child: _RunList(
              async: async,
              sessions: list,
              filtered: _filtered,
              padding: EdgeInsets.fromLTRB(pad, 4, pad, 24),
              headerInset: 8,
              onTap: _openRun,
              onClearFilters: _clearFilters,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tablet(AsyncValue<List<Session>> async, List<Session> list) {
    final selectedId = ref.watch(selectedSessionIdProvider);
    final selected = list.where((s) => s.id == selectedId).firstOrNull ?? list.firstOrNull;
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.surface,
      body: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PulseEntrance(
              fromLeft: true,
              offset: 10,
              child: PulsePane(
                width: 420,
                padding: const EdgeInsets.fromLTRB(12, 20, 12, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: PulsePaneHeader(
                        title: 'History',
                        actions: [
                          PulseIconButton(
                            icon: PulseIcons.export,
                            tooltip: 'Export',
                            onPressed: () => _openExport(list),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: _FilterField(
                        controller: _search,
                        onChanged: (v) => ref.read(historyFilterProvider.notifier).setSearch(v),
                      ),
                    ),
                    const SizedBox(height: 6),
                    _chipRow(small: true, padding: const EdgeInsets.symmetric(horizontal: 4)),
                    Expanded(
                      child: _RunList(
                        async: async,
                        sessions: list,
                        filtered: _filtered,
                        selectedId: selected?.id,
                        rowColor: c.surfaceContainerHigh,
                        padding: const EdgeInsets.only(bottom: 12),
                        headerInset: 12,
                        compactEmpty: true,
                        onTap: (s) => ref.read(selectedSessionIdProvider.notifier).select(s.id),
                        onClearFilters: _clearFilters,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: selected == null
                  ? Center(
                      child: async.isLoading
                          ? const SizedBox.shrink()
                          : _filtered
                          ? PulseEmptyState(
                              title: 'Nothing selected',
                              message: 'No run matches this filter.',
                              icon: PulseIcons.search,
                              shape: PulseShape.clover4,
                              action: _Fit(
                                PulseButton(
                                  label: 'Clear filters',
                                  style: PulseButtonStyle.tonal,
                                  onPressed: _clearFilters,
                                ),
                              ),
                            )
                          : PulseEmptyState(
                              title: 'No runs yet',
                              message: 'Every ping, traceroute, speed test and scan you finish lands here.',
                              icon: PulseIcons.clock,
                              action: _Fit(
                                PulseButton(
                                  label: 'Start a ping',
                                  icon: PulseIcons.pulse,
                                  onPressed: () => context.go(Routes.ping),
                                ),
                              ),
                            ),
                    )
                  : KeyedSubtree(
                      key: ValueKey(selected.id),
                      child: RunDetail(session: selected),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The day-grouped run list shared by the phone screen and the tablet pane.
class _RunList extends ConsumerWidget {
  const _RunList({
    required this.async,
    required this.sessions,
    required this.filtered,
    required this.onTap,
    required this.onClearFilters,
    required this.padding,
    required this.headerInset,
    this.selectedId,
    this.rowColor,
    this.compactEmpty = false,
  });

  final AsyncValue<List<Session>> async;
  final List<Session> sessions;
  final bool filtered;
  final ValueChanged<Session> onTap;
  final VoidCallback onClearFilters;
  final EdgeInsetsGeometry padding;
  final double headerInset;
  final int? selectedId;
  final Color? rowColor;
  final bool compactEmpty;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (async.hasError && sessions.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Align(
          alignment: Alignment.topCenter,
          child: PulseErrorBanner(
            title: 'Could not load history',
            message: '${async.error}',
            onRetry: () => ref.invalidate(historyProvider),
          ),
        ),
      );
    }
    if (sessions.isEmpty) {
      if (async.isLoading) return const SizedBox.shrink();
      return SingleChildScrollView(
        padding: padding,
        child: filtered
            ? PulseEmptyState(
                title: 'No matches',
                message: 'Nothing in History matches that filter.',
                icon: PulseIcons.search,
                shape: PulseShape.clover4,
                size: compactEmpty ? 88 : 120,
                action: _Fit(
                  PulseButton(label: 'Clear filters', style: PulseButtonStyle.tonal, onPressed: onClearFilters),
                ),
              )
            : compactEmpty
            ? Padding(
                padding: EdgeInsets.fromLTRB(headerInset, 16, 12, 0),
                child: Text(
                  'Finished runs show up here.',
                  style: context.type.bodyMedium!.copyWith(color: context.colors.onSurfaceVariant),
                ),
              )
            : PulseEmptyState(
                title: 'No runs yet',
                message: 'Every ping, traceroute, speed test and scan you finish lands here.',
                icon: PulseIcons.clock,
                action: _Fit(
                  PulseButton(label: 'Start a ping', icon: PulseIcons.pulse, onPressed: () => context.go(Routes.ping)),
                ),
              ),
      );
    }

    // Flatten into headers and rows so long histories build lazily.
    final entries = <Object>[];
    for (final (day, runs) in groupByDay(sessions)) {
      entries.add('$day · ${runs.length} run${runs.length == 1 ? '' : 's'}');
      for (var i = 0; i < runs.length; i++) {
        entries.add((runs[i], i, runs.length));
      }
    }
    return ListView.builder(
      padding: padding,
      itemCount: entries.length,
      itemBuilder: (context, i) {
        final e = entries[i];
        final Widget child;
        if (e is String) {
          child = Padding(
            padding: EdgeInsets.fromLTRB(headerInset, i == 0 ? 12 : 20, 0, 8),
            child: Semantics(
              header: true,
              child: Text(e, style: context.type.titleSmall!.copyWith(color: context.colors.onSurfaceVariant)),
            ),
          );
        } else {
          final (s, index, count) = e as (Session, int, int);
          child = Padding(
            padding: EdgeInsets.only(top: index == 0 ? 0 : 3),
            child: _RunRow(
              info: RunInfo(s),
              selected: s.id == selectedId,
              radius: segmentedRadius(index, count),
              color: rowColor,
              onTap: () => onTap(s),
            ),
          );
        }
        return i < 14 ? PulseEntrance(index: i, child: child) : child;
      },
    );
  }
}

/// A History row: the tool's badge, target, "time · tool · detail" and the
/// result on the right. Selected rows turn fully round in secondaryContainer.
class _RunRow extends StatelessWidget {
  const _RunRow({required this.info, required this.selected, required this.radius, required this.onTap, this.color});

  final RunInfo info;
  final bool selected;
  final BorderRadius radius;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tool = info.tool;
    final fg = selected ? c.onSecondaryContainer : c.onSurface;
    final sub = selected ? c.onSecondaryContainer.withValues(alpha: .85) : c.onSurfaceVariant;
    return Semantics(
      button: true,
      selected: selected,
      label: info.semantics,
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: PulseMotion.shapeMorph,
        curve: PulseMotion.spring,
        decoration: BoxDecoration(
          color: selected ? c.secondaryContainer : (color ?? c.surfaceContainer),
          borderRadius: selected ? BorderRadius.circular(31) : radius,
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 62),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 16, 8),
                child: Row(
                  children: [
                    PulseShapeBadge(shape: tool.shape, tone: tool.tone, icon: tool.icon),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            info.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.type.titleMedium!.copyWith(color: fg),
                          ),
                          Text(
                            info.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.type.bodySmall!.copyWith(color: sub),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 150),
                      child: Text(
                        info.result,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                        style: pulseNumber(18).copyWith(color: fg),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The pane's 48 dp filter field on surfaceContainerHighest.
class _FilterField extends StatelessWidget {
  const _FilterField({required this.controller, required this.onChanged});
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final style = context.type.bodyLarge!.copyWith(fontSize: 15, fontWeight: FontWeight.w500);
    return Container(
      height: 48,
      padding: const EdgeInsets.only(left: 16, right: 4),
      decoration: BoxDecoration(color: c.surfaceContainerHighest, borderRadius: BorderRadius.circular(24)),
      child: Row(
        children: [
          PulseIcon(PulseIcons.search, size: 20, color: c.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              autocorrect: false,
              style: style.copyWith(color: c.onSurface),
              cursorColor: c.primary,
              decoration: InputDecoration.collapsed(
                hintText: 'Filter by name or host',
                hintStyle: style.copyWith(color: c.onSurfaceVariant),
              ),
            ),
          ),
          ListenableBuilder(
            listenable: controller,
            builder: (context, _) => controller.text.isEmpty
                ? const SizedBox(width: 12)
                : PulseIconButton(
                    icon: PulseIcons.x,
                    tooltip: 'Clear filter',
                    iconSize: 18,
                    visualSize: 32,
                    onPressed: () {
                      controller.clear();
                      onChanged('');
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// Export: format (CSV · JSON · Text) and scope (all runs or the filtered list).
class _ExportSheet extends StatefulWidget {
  const _ExportSheet({required this.initial, required this.filteredCount});
  final ExportFormat initial;

  /// Null when no filter is active.
  final int? filteredCount;

  @override
  State<_ExportSheet> createState() => _ExportSheetState();
}

class _ExportSheetState extends State<_ExportSheet> {
  late ExportFormat _format = widget.initial;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final n = widget.filteredCount;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Export history', style: context.type.titleLarge),
            const SizedBox(height: 4),
            Text(
              'CSV opens in spreadsheets. JSON keeps every sample of each run.',
              style: context.type.bodyMedium!.copyWith(color: c.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            PulseButtonGroup<ExportFormat>(
              segments: const [
                PulseSegment(ExportFormat.csv, 'CSV'),
                PulseSegment(ExportFormat.json, 'JSON'),
                PulseSegment(ExportFormat.txt, 'Text'),
              ],
              selected: _format,
              onChanged: (f) => setState(() => _format = f),
            ),
            const SizedBox(height: 20),
            PulseButton(
              label: 'Export all runs',
              icon: PulseIcons.export,
              size: PulseButtonSize.large,
              expand: true,
              onPressed: () => Navigator.pop(context, (_format, true)),
            ),
            if (n != null) ...[
              const SizedBox(height: 8),
              PulseButton(
                label: 'Export filtered · $n run${n == 1 ? '' : 's'}',
                icon: PulseIcons.filter,
                style: PulseButtonStyle.tonal,
                size: PulseButtonSize.large,
                expand: true,
                onPressed: n == 0 ? null : () => Navigator.pop(context, (_format, false)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Keeps a [PulseButton] at its natural width inside a stretching column.
class _Fit extends StatelessWidget {
  const _Fit(this.child);
  final Widget child;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [child]);
}
