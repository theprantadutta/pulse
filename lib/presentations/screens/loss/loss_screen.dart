import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/format.dart';
import '../../../core/widgets/pulse/pulse.dart';
import '../../../data/models/app_settings.dart';
import '../../../providers/loss_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../services/export_service.dart';
import '../../navigation/destinations.dart';
import 'loss_widgets.dart';

const _durations = [1, 5, 15, 60];
const _rates = [1, 2, 5];

/// The RTT chart shows at most this many of the newest packets.
const _maxBars = 240;

/// 09 Packet loss: burst hero with the loss %, a verdict, stats, elapsed
/// progress, one timeline cell per packet and (tablet) a round-trip chart.
class LossScreen extends ConsumerStatefulWidget {
  const LossScreen({super.key, this.initialTarget});
  final String? initialTarget;

  @override
  ConsumerState<LossScreen> createState() => _LossScreenState();
}

class _LossScreenState extends ConsumerState<LossScreen> {
  late final _target = TextEditingController(text: widget.initialTarget ?? ref.read(lossProvider).target);

  @override
  void dispose() {
    _target.dispose();
    super.dispose();
  }

  void _start() {
    FocusScope.of(context).unfocus();
    ref.read(lossProvider.notifier).start(_target.text);
  }

  Future<void> _export() async {
    final messenger = ScaffoldMessenger.of(context);
    final s = ref.read(lossProvider);
    final path = await const ExportService().save(
      fileName: ExportService.stampedName('loss-${s.target}', ExportFormat.csv),
      content: ref.read(lossProvider.notifier).toCsv(),
      settings: ref.read(settingsProvider),
    );
    if (path != null) messenger.showSnackBar(SnackBar(content: Text('Saved $path')));
  }

  /// Creates a loss rule from this run and opens it in the rule editor.
  Future<void> _alert() async {
    final id = await ref.read(lossProvider.notifier).createLossAlert();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Loss alert created')));
    context.push('${Routes.alertRule}?id=$id');
  }

  Future<void> _pick(
    BuildContext anchor,
    List<int> values,
    int current,
    String Function(int) label,
    void Function(int) onPicked,
  ) async {
    final box = anchor.findRenderObject()! as RenderBox;
    final overlay = Overlay.of(anchor).context.findRenderObject()! as RenderBox;
    final topLeft = box.localToGlobal(Offset(0, box.size.height), ancestor: overlay);
    final v = await showMenu<int>(
      context: anchor,
      position: RelativeRect.fromRect(topLeft & box.size, Offset.zero & overlay.size),
      items: [for (final x in values) CheckedPopupMenuItem(value: x, checked: x == current, child: Text(label(x)))],
    );
    if (v != null) onPicked(v);
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(lossProvider);
    final n = ref.read(lossProvider.notifier);
    final compact = context.isCompact;
    return LayoutBuilder(
      builder: (context, box) {
        final wide = !compact && box.maxWidth >= 720;
        final actions = <Widget>[
          if (wide) ...[
            SizedBox(
              width: (box.maxWidth - 2 * PulseLayout.tabletPadding - 560).clamp(180, 460).toDouble(),
              child: _field(s, compact: false),
            ),
            Builder(
              builder: (anchor) => PulseChip(
                label: '${s.durationMin} min',
                icon: PulseIcons.timer,
                onTap: s.running
                    ? null
                    : () => _pick(anchor, _durations, s.durationMin, (v) => '$v min', n.setDuration),
              ),
            ),
            Builder(
              builder: (anchor) => PulseChip(
                label: '${s.ratePerSec} / s',
                onTap: s.running ? null : () => _pick(anchor, _rates, s.ratePerSec, (v) => '$v per second', n.setRate),
              ),
            ),
            if (s.running)
              PulseButton(label: 'Stop', icon: PulseIcons.stop, size: PulseButtonSize.large, onPressed: n.stop)
            else
              PulseButton(label: 'Start', icon: PulseIcons.play, size: PulseButtonSize.large, onPressed: _start),
          ] else if (s.running)
            PulseButton(
              label: 'Stop',
              icon: PulseIcons.stop,
              style: PulseButtonStyle.tonal,
              size: PulseButtonSize.small,
              onPressed: n.stop,
            ),
        ];
        return PulsePage(
          title: 'Packet loss',
          backTo: Routes.tools,
          actions: actions,
          body: wide ? _tablet(context, s) : _phone(context, s),
        );
      },
    );
  }

  Widget _field(LossState s, {required bool compact}) => PulseTargetField(
    controller: _target,
    hint: 'Host or IP, e.g. 1.1.1.1',
    enabled: !s.running,
    onSubmitted: (_) => _start(),
    trailing: compact ? '${s.durationMin} min · ${s.ratePerSec}/s' : (s.address != s.target ? s.address : null),
  );

  // -------------------------------------------------------------------------
  // Phone
  // -------------------------------------------------------------------------

  Widget _phone(BuildContext context, LossState s) {
    final r = s.run;
    final hasRun = r.packets.isNotEmpty;
    return ListView(
      padding: EdgeInsets.fromLTRB(context.pagePadding, 4, context.pagePadding, 24),
      children: [
        for (final (i, w) in [
          _field(s, compact: true),
          if (!s.running) _Options(state: s, onStart: _start, again: hasRun),
          if (s.error != null) _ErrorBanner(message: s.error!, onRetry: _start),
          if (hasRun) ...[
            _HeroRow(state: s, heroSize: 170),
            _Stats(run: r, long: false),
            _Progress(state: s),
            _TimelineCard(run: r, columns: 30, long: false),
            if (r.sent > 0) _RttCard(run: r),
            if (s.compare != null) _CompareCard(state: s),
            _Actions(state: s, onExport: _export, onAlert: _alert),
          ] else if (s.error == null)
            const PulseEmptyState(
              title: 'Not run yet',
              message: 'Sends steady pings for the whole duration and charts every packet, so short drops show up.',
              icon: PulseIcons.loss,
              shape: PulseShape.clover4,
            ),
        ].indexed)
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : 14),
            child: PulseEntrance(index: i, child: w),
          ),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // Tablet
  // -------------------------------------------------------------------------

  Widget _tablet(BuildContext context, LossState s) {
    final r = s.run;
    final hasRun = r.packets.isNotEmpty;
    final children = <Widget>[
      if (s.error != null) _ErrorBanner(message: s.error!, onRetry: _start),
      if (hasRun) ...[
        _HeroRow(state: s, heroSize: 230),
        _Progress(state: s),
        _TimelineCard(run: r, columns: 60, long: true),
        if (r.sent > 0) _RttCard(run: r),
        if (s.compare != null) _CompareCard(state: s),
        _Actions(state: s, onExport: _export, onAlert: _alert),
      ] else ...[
        if (s.error == null)
          const PulseEmptyState(
            title: 'Not run yet',
            message: 'Pick a target, duration and rate, then Start. Every packet gets a cell in the timeline.',
            icon: PulseIcons.loss,
            shape: PulseShape.clover4,
            size: 140,
          ),
      ],
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(PulseLayout.tabletPadding, 4, PulseLayout.tabletPadding, 24),
      children: [
        for (var i = 0; i < children.length; i++)
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : 16),
            child: PulseEntrance(index: i, child: children[i]),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Sections
// ---------------------------------------------------------------------------

/// Idle: duration and rate as connected groups, then the pink Start.
class _Options extends ConsumerWidget {
  const _Options({required this.state, required this.onStart, required this.again});
  final LossState state;
  final VoidCallback onStart;
  final bool again;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = ref.read(lossProvider.notifier);
    final label = context.type.labelMedium!.copyWith(color: context.colors.onSurfaceVariant);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 0, 6),
          child: Text('Duration', style: label),
        ),
        PulseButtonGroup<int>(
          small: true,
          selected: state.durationMin,
          onChanged: n.setDuration,
          segments: [for (final d in _durations) PulseSegment(d, '$d min')],
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 0, 6),
          child: Text('Rate', style: label),
        ),
        PulseButtonGroup<int>(
          small: true,
          selected: state.ratePerSec,
          onChanged: n.setRate,
          segments: [for (final r in _rates) PulseSegment(r, '$r / s')],
        ),
        ...[
          const SizedBox(height: 16),
          PulseButton(
            label: again ? 'Run again' : 'Start',
            icon: again ? PulseIcons.refresh : PulseIcons.play,
            size: PulseButtonSize.large,
            expand: true,
            onPressed: onStart,
          ),
        ],
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) =>
      PulseErrorBanner(title: "Couldn't reach the target", message: message, onRetry: onRetry);
}

/// Burst hero + verdict pill + one-sentence verdict (+ stats on tablet).
class _HeroRow extends StatelessWidget {
  const _HeroRow({required this.state, required this.heroSize});
  final LossState state;
  final double heroSize;

  @override
  Widget build(BuildContext context) {
    final s = state;
    final r = s.run;
    final big = heroSize >= 200;
    final v = lossVerdict(s);
    final (pill, tone) = verdictPill(v.word);
    final scaler = MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.3);
    final on = PulseTone.pink.on(context);
    final value = r.sent == 0 ? '—' : '${r.lossPct.toStringAsFixed(1)}%';
    final hero = PulsePop(
      child: Semantics(
        label: r.sent == 0 ? 'Packet loss, no replies yet' : 'Packet loss $value',
        liveRegion: s.running,
        excludeSemantics: true,
        child: PulseShapeBox(
          shape: PulseShape.burst,
          color: PulseTone.pink.fill(context),
          size: heroSize,
          spin: s.running ? PulseMotion.heroSpin : null,
          child: Padding(
            padding: EdgeInsets.all(heroSize * .16),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: MediaQuery(
                data: MediaQuery.of(context).copyWith(textScaler: scaler),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Loss', style: pulseText(big ? 15 : 13, 700).copyWith(color: on)),
                    PulseLiveValue(
                      value,
                      style: pulseText(
                        big ? 56 : 46,
                        900,
                        wdth: big ? 100 : 110,
                        height: .95,
                        tracking: -.03,
                      ).copyWith(color: on),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final verdict = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            PulsePill(pill, tone: tone, height: big ? 32 : 30),
            if (big)
              Text(
                s.running ? 'Verdict so far' : 'Verdict',
                style: context.type.bodySmall!.copyWith(color: context.colors.onSurfaceVariant),
              ),
          ],
        ),
        SizedBox(height: big ? 14 : 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Text(
            v.text,
            style: (big ? context.type.bodyLarge!.copyWith(fontSize: 18) : context.type.bodyMedium)!.copyWith(
              height: 1.4,
            ),
          ),
        ),
        if (big) ...[const SizedBox(height: 16), _Stats(run: r, long: true)],
      ],
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        hero,
        SizedBox(width: big ? 24 : 14),
        Expanded(child: verdict),
      ],
    );
  }
}

class _Stats extends StatelessWidget {
  const _Stats({required this.run, required this.long});
  final LossRun run;
  final bool long;

  @override
  Widget build(BuildContext context) => PulseStatRow(
    valueSize: long ? 26 : 22,
    stats: [
      PulseStat('Sent', '${run.sent}'),
      PulseStat('Lost', '${run.lost}', color: run.lost > 0 ? context.pulse.latSlow : null),
      PulseStat(long ? 'Late >150 ms' : 'Late', '${run.late}'),
      PulseStat(long ? 'Longest burst' : 'Longest', '${run.longestBurst}'),
    ],
  );
}

class _Progress extends StatelessWidget {
  const _Progress({required this.state});
  final LossState state;

  @override
  Widget build(BuildContext context) {
    final s = state;
    final r = s.run;
    final total = Duration(minutes: s.durationMin);
    final progress = s.total == 0 ? 0.0 : r.sent / s.total;
    final elapsed = s.running
        ? (s.elapsed > total ? total : s.elapsed)
        : Duration(seconds: r.sent ~/ math.max(1, s.ratePerSec));
    final label = s.running
        ? 'Elapsed ${fmtClock(elapsed)} of ${fmtClock(total)}'
        : progress >= 1
        ? 'Finished · ${fmtClock(total)}'
        : 'Stopped at ${fmtClock(elapsed)} of ${fmtClock(total)}';
    final style = context.type.bodySmall!.copyWith(color: context.colors.onSurfaceVariant);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: style)),
              Text('${(progress * 100).round()}%', style: style),
            ],
          ),
          const SizedBox(height: 6),
          PulseWavyBar(value: progress, semanticLabel: label),
        ],
      ),
    );
  }
}

class _TimelineCard extends StatelessWidget {
  const _TimelineCard({required this.run, required this.columns, required this.long});
  final LossRun run;
  final int columns;
  final bool long;

  @override
  Widget build(BuildContext context) {
    final t = context.pulse;
    final per = packetsPerCell(run.packets.length);
    final unit = per == 1 ? '1 cell = 1 packet' : '1 cell = $per packets';
    final legend = Wrap(
      spacing: 12,
      children: [
        LegendDot(color: t.latFast, label: 'OK'),
        LegendDot(color: t.latMedium, label: 'Late'),
        LegendDot(color: t.latSlow, label: 'Lost'),
      ],
    );
    return PulseCard(
      padding: EdgeInsets.fromLTRB(long ? 18 : 16, 14, long ? 18 : 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  long || per > 1 ? 'Timeline · $unit' : 'Timeline',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.type.titleMedium,
                ),
              ),
              legend,
            ],
          ),
          SizedBox(height: long ? 12 : 10),
          LossTimeline(run: run, columns: columns, gap: long ? 3 : 2.4),
        ],
      ),
    );
  }
}

class _RttCard extends StatelessWidget {
  const _RttCard({required this.run});
  final LossRun run;

  @override
  Widget build(BuildContext context) {
    final values = <double?>[
      for (var i = 0; i < run.packets.length; i++)
        if (run.packets[i] != PacketState.pending) run.rtts[i],
    ];
    final shown = values.length > _maxBars ? values.sublist(values.length - _maxBars) : values;
    final present = run.rtts.whereType<double>();
    final max = present.isEmpty ? null : present.reduce(math.max);
    final summary = [
      if (run.avgRtt != null) 'avg ${fmtMs(run.avgRtt)} ms',
      if (max != null) 'max ${fmtMs(max)} ms',
      if (values.length > _maxBars) 'last $_maxBars',
    ].join(' · ');
    return PulseCard(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text('Round-trip time', style: context.type.titleMedium)),
              Text(summary, style: context.type.labelMedium!.copyWith(color: context.colors.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: 12),
          PulseBars(values: shown, height: 70, barWidth: 5, gap: 3.9, fill: true),
        ],
      ),
    );
  }
}

/// The parallel run against 1.1.1.1 (or 8.8.8.8).
class _CompareCard extends StatelessWidget {
  const _CompareCard({required this.state});
  final LossState state;

  @override
  Widget build(BuildContext context) {
    final c = state.compare!;
    final c0 = context.colors;
    return PulseCard(
      color: c0.surfaceContainerHigh,
      radius: 24,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          PulseShapeBadge(shape: PulseShape.clover4, tone: PulseTone.lavender, icon: PulseIcons.loss, size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Compared with ${state.compareHost}', style: context.type.titleSmall),
                Text(
                  c.sent == 0
                      ? 'Waiting for replies…'
                      : '${c.sent} sent · ${c.lost} lost${c.avgRtt == null ? '' : ' · avg ${fmtMs(c.avgRtt)} ms'}',
                  style: context.type.bodySmall!.copyWith(color: c0.onSurfaceVariant),
                ),
              ],
            ),
          ),
          PulseNumber(c.sent == 0 ? '—' : c.lossPct.toStringAsFixed(1), unit: '%', live: true, unitScale: .6),
        ],
      ),
    );
  }
}

class _Actions extends ConsumerWidget {
  const _Actions({required this.state, required this.onExport, required this.onAlert});
  final LossState state;
  final VoidCallback onExport, onAlert;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = state;
    final n = ref.read(lossProvider.notifier);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final b in [
          PulseButton(
            label: 'Export CSV',
            icon: PulseIcons.export,
            style: PulseButtonStyle.outlined,
            onPressed: s.run.sent == 0 ? null : onExport,
          ),
          PulseButton(
            label: 'Alert on loss',
            icon: PulseIcons.bell,
            style: PulseButtonStyle.tonal,
            onPressed: s.target.isEmpty ? null : onAlert,
          ),
          if (s.running || s.compare != null)
            PulseButton(
              label: s.compare == null ? 'Compare with ${s.compareHost}' : 'Comparing with ${s.compareHost}',
              icon: PulseIcons.loss,
              style: PulseButtonStyle.outlined,
              tooltip: 'Ping ${s.compareHost} alongside to tell your link from the target',
              onPressed: s.running && s.compare == null ? n.compareToCloudflare : null,
            ),
        ])
          IntrinsicWidth(child: b),
      ],
    );
  }
}
