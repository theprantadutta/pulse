import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/widgets/pulse/pulse.dart';
import '../../../data/models/app_settings.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/trace_provider.dart';
import '../../../services/export_service.dart';
import '../../navigation/destinations.dart';
import 'trace_insights.dart';
import 'trace_widgets.dart';

/// 06 Traceroute. Phone: target, "56 ms to reach" summary, route rail and
/// highlights (full list in a sheet). Tablet: full hop list on the left, the
/// destination card, rail, biggest-jump explanation and Copy / Save on the right.
class TraceScreen extends ConsumerStatefulWidget {
  const TraceScreen({super.key, this.initialTarget});
  final String? initialTarget;

  @override
  ConsumerState<TraceScreen> createState() => _TraceScreenState();
}

class _TraceScreenState extends ConsumerState<TraceScreen> {
  late final _target = TextEditingController(text: widget.initialTarget ?? ref.read(traceProvider).target);
  final _targetFocus = FocusNode();

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
    _targetFocus.dispose();
    super.dispose();
  }

  void _run() {
    if (_target.text.trim().isEmpty) {
      showPulseToast(context, 'Enter a host or IP address first', icon: PulseIcons.search);
      _targetFocus.requestFocus();
      return;
    }
    FocusScope.of(context).unfocus();
    ref.read(traceProvider.notifier).run(_target.text);
  }

  void _toggle() => ref.read(traceProvider).running ? ref.read(traceProvider.notifier).stop() : _run();

  void _snack(String text) => ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  Future<void> _copy(TraceState s) async {
    await Clipboard.setData(ClipboardData(text: s.toText()));
    _snack('Route copied');
  }

  Future<void> _save(TraceState s) async {
    try {
      final path = await const ExportService().save(
        fileName: ExportService.stampedName('trace-${s.target}', ExportFormat.txt),
        content: s.toText(),
        settings: ref.read(settingsProvider),
      );
      if (path != null && mounted) _snack('Saved $path');
    } on Object catch (e) {
      if (mounted) _snack("Couldn't save: $e");
    }
  }

  Future<void> _options() => showModalBottomSheet<void>(
    useRootNavigator: true,
    context: context,
    builder: (context) => Consumer(
      builder: (context, ref, _) {
        final s = ref.watch(traceProvider);
        final n = ref.read(traceProvider.notifier);
        final label = context.type.titleSmall!.copyWith(color: context.colors.onSurfaceVariant);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Trace options', style: context.type.titleLarge),
                if (s.running) ...[
                  const SizedBox(height: 4),
                  Text('Stop the trace to change these.', style: context.type.bodySmall!.copyWith(color: label.color)),
                ],
                const SizedBox(height: 20),
                Text('Max hops', style: label),
                const SizedBox(height: 8),
                PulseButtonGroup<int>(
                  segments: const [PulseSegment(15, '15'), PulseSegment(30, '30'), PulseSegment(64, '64')],
                  selected: s.maxHops,
                  onChanged: s.running ? null : n.setMaxHops,
                ),
                const SizedBox(height: 20),
                Text('Probes per hop', style: label),
                const SizedBox(height: 8),
                PulseButtonGroup<int>(
                  segments: const [PulseSegment(1, '1'), PulseSegment(3, '3'), PulseSegment(5, '5')],
                  selected: s.probes,
                  onChanged: s.running ? null : n.setProbes,
                ),
              ],
            ),
          ),
        );
      },
    ),
  );

  Future<void> _seeAll() => showModalBottomSheet<void>(
    useRootNavigator: true,
    context: context,
    isScrollControlled: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: .85,
      maxChildSize: .95,
      builder: (context, controller) => Consumer(
        builder: (context, ref, _) {
          final s = ref.watch(traceProvider);
          final ins = _insights(s);
          return ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
                child: Text('All hops · ${s.hops.length}', style: context.type.titleLarge),
              ),
              if (ins.jump != null) ...[TraceJumpCard(insights: ins), const SizedBox(height: 12)],
              TraceHopList(insights: ins, running: s.running, collapse: false),
            ],
          );
        },
      ),
    ),
  );

  TraceInsights _insights(TraceState s) =>
      TraceInsights.of(s.hops, target: s.target, reached: s.reached, finished: s.finished && !s.running);

  double _progress(TraceState s) {
    final done = s.hops.where((h) => h.done).length;
    if (s.reached && s.hops.isNotEmpty) return done / s.hops.length;
    return (done / s.maxHops).clamp(0, 1).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(traceProvider);
    final ins = _insights(s);
    final compact = context.isCompact;
    final idle = s.hops.isEmpty && !s.running && s.error == null;
    final runLabel = s.running
        ? 'Stop'
        : s.hops.isEmpty
        ? 'Trace'
        : 'Run again';
    final runIcon = s.running
        ? PulseIcons.stop
        : s.hops.isEmpty
        ? PulseIcons.play
        : PulseIcons.refresh;

    final field = PulseTargetField(
      controller: _target,
      hint: 'Host or IP to trace',
      enabled: !s.running,
      focusNode: _targetFocus,
      onSubmitted: (_) => _run(),
      trailing: compact ? s.destination : null,
      trailingWidget: compact ? null : _OptionsLabel(state: s, onTap: s.running ? null : _options),
    );
    final progress = s.running
        ? Padding(
            padding: const EdgeInsets.only(top: 10),
            child: PulseWavyBar(value: _progress(s), semanticLabel: 'Tracing'),
          )
        : null;
    final error = s.error == null
        ? null
        : PulseErrorBanner(title: "Couldn't trace ${s.target}", message: s.error, onRetry: s.running ? null : _run);
    final empty = const PulseEmptyState(
      title: 'Trace a route',
      message: 'Enter a host to see every router between you and it, and where the delay is added.',
      shape: PulseShape.arch,
      icon: PulseIcons.route,
    );
    final actions = Row(
      children: [
        Expanded(
          child: PulseButton(
            label: 'Copy',
            icon: PulseIcons.copy,
            style: PulseButtonStyle.tonal,
            expand: true,
            onPressed: s.hops.isEmpty ? null : () => _copy(s),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: PulseButton(
            label: 'Save',
            icon: PulseIcons.export,
            style: PulseButtonStyle.tonal,
            expand: true,
            onPressed: s.hops.isEmpty ? null : () => _save(s),
          ),
        ),
      ],
    );

    // Phone (and narrow tablet) single column.
    List<Widget> column({required bool fullList}) => [
      Padding(padding: const EdgeInsets.only(top: 4), child: field),
      ?progress,
      if (error != null) Padding(padding: const EdgeInsets.only(top: 12), child: error),
      if (idle)
        empty
      else ...[
        if (s.hops.isNotEmpty || s.running)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 14, 4, 0),
            child: TraceSummary(insights: ins, running: s.running),
          ),
        if (s.hops.isNotEmpty || s.running)
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: TraceRouteCard(insights: ins),
          ),
        if (fullList) ...[
          if (ins.jump != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: TraceJumpCard(insights: ins),
            ),
          PulseSectionLabel('Hops', padding: const EdgeInsets.fromLTRB(4, 16, 0, 8)),
          TraceHopList(insights: ins, running: s.running),
        ] else if (s.hops.isNotEmpty) ...[
          PulseSectionLabel(
            'Highlights',
            padding: const EdgeInsets.fromLTRB(4, 12, 0, 4),
            trailing: TextButton(onPressed: _seeAll, child: Text('See all ${s.hops.length}')),
          ),
          TraceHighlights(insights: ins, running: s.running, maxHops: s.maxHops),
        ],
        if (s.hops.isNotEmpty && !s.running) Padding(padding: const EdgeInsets.only(top: 16), child: actions),
      ],
    ];

    if (compact) {
      return PulsePage(
        title: 'Traceroute',
        backTo: Routes.tools,
        actions: [
          PulseIconButton(icon: PulseIcons.tune, tooltip: 'Trace options', onPressed: _options),
          PulseIconButton(
            icon: runIcon,
            tooltip: runLabel,
            style: PulseIconButtonStyle.pink,
            visualSize: 48,
            onPressed: _toggle,
          ),
        ],
        children: column(fullList: false),
      );
    }

    // Width left for this screen next to the rail (and the Tools pane on
    // expanded layouts). Below 760 the field gets its own row instead of
    // being squeezed between the title and the Trace button.
    final contentWidth =
        MediaQuery.sizeOf(context).width - PulseLayout.rail - (context.isExpanded ? PulseLayout.pane : 0);
    final inlineField = contentWidth >= 760;
    return PulsePage(
      title: 'Traceroute',
      titleWidget: inlineField
          ? Row(
              children: [
                Text('Traceroute', style: context.type.headlineMedium),
                const SizedBox(width: 16),
                Expanded(child: field),
              ],
            )
          : null,
      actions: [PulseButton(label: runLabel, icon: runIcon, size: PulseButtonSize.large, onPressed: _toggle)],
      body: LayoutBuilder(
        builder: (context, box) {
          final pad = context.pagePadding;
          if (box.maxWidth < 760) {
            final items = column(fullList: true).skip(inlineField ? 1 : 0).toList();
            return ListView(
              padding: EdgeInsets.fromLTRB(pad, 0, pad, 24),
              children: [for (var i = 0; i < items.length; i++) PulseEntrance(index: i, child: items[i])],
            );
          }
          return Padding(
            padding: EdgeInsets.fromLTRB(pad, 0, pad, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (progress != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: progress),
                if (error != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: error),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: idle
                            ? Center(child: SingleChildScrollView(child: empty))
                            : ListView(
                                padding: const EdgeInsets.only(bottom: 24),
                                children: [TraceHopList(insights: ins, running: s.running)],
                              ),
                      ),
                      const SizedBox(width: 16),
                      SizedBox(
                        width: PulseLayout.pane,
                        child: CustomScrollView(
                          slivers: [
                            SliverList.list(
                              children: [
                                PulseEntrance(
                                  index: 0,
                                  child: TraceDestinationCard(insights: ins, running: s.running),
                                ),
                                const SizedBox(height: 12),
                                PulseEntrance(index: 1, child: TraceRouteCard(insights: ins)),
                                if (ins.jump != null) ...[
                                  const SizedBox(height: 12),
                                  PulseEntrance(index: 2, child: TraceJumpCard(insights: ins)),
                                ],
                              ],
                            ),
                            SliverFillRemaining(
                              hasScrollBody: false,
                              child: Align(
                                alignment: Alignment.bottomCenter,
                                child: Padding(padding: const EdgeInsets.fromLTRB(0, 16, 0, 20), child: actions),
                              ),
                            ),
                          ],
                        ),
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
  }
}

/// Tablet field trailing: "20.205.243.166 · max 30 hops · 3 probes"; tapping
/// the options part opens the options sheet.
class _OptionsLabel extends StatelessWidget {
  const _OptionsLabel({required this.state, required this.onTap});
  final TraceState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final style = context.type.bodySmall!.copyWith(color: context.colors.onSurfaceVariant);
    final opts = 'max ${state.maxHops} hops · ${state.probes} probe${state.probes == 1 ? '' : 's'}';
    return Flexible(
      flex: 2,
      child: Padding(
        padding: const EdgeInsets.only(left: 8),
        child: Tooltip(
          message: 'Trace options',
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Align(
                  alignment: Alignment.centerRight,
                  widthFactor: 1,
                  child: Text(
                    [?state.destination, opts].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: style,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
