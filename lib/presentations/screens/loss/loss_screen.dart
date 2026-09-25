import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/format.dart';
import '../../../core/widgets/wire/wire.dart';
import '../../../core/widgets/wire/wire_page.dart';
import '../../../data/models/app_settings.dart';
import '../../../providers/loss_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../services/export_service.dart';
import '../../navigation/destinations.dart';
import '../tools/tool_widgets.dart';

/// 11 — Packet loss test.
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

  void _start() => ref.read(lossProvider.notifier).start(_target.text);

  String _clock(Duration d) => '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

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

  Future<void> _alert() async {
    await ref.read(lossProvider.notifier).createLossAlert();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Loss alert created')));
    context.go(Routes.alerts);
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(lossProvider);
    final n = ref.read(lossProvider.notifier);
    final w = context.wire;
    final r = s.run;
    final verdict = lossVerdict(s);
    final lossText = r.sent == 0 ? '—' : '${r.lossPct.toStringAsFixed(1)}%';
    final progress = s.total == 0 ? 0.0 : r.sent / s.total;
    final elapsed = s.running ? s.elapsed : Duration(seconds: r.sent ~/ math.max(1, s.ratePerSec));
    final heroSignal = r.lost > 0 || s.running;

    return WireAdaptive(
      mobile: (context) => WireMobilePage(
        header: WireMobileHeader(
          title: 'Packet loss',
          onBack: mobileBack(context),
          trailing: Text(s.startedAt == null ? '' : _clock(elapsed), style: WireType.label(12).copyWith(color: w.signal)),
        ),
        body: ListView(
          padding: EdgeInsets.zero,
          children: [
            MobileTargetRow(controller: _target, onSubmitted: (_) => _start(), enabled: !s.running),
            if (s.error != null) WireErrorBlock(reason: s.error!, size: 56),
            Container(
              color: heroSignal ? w.signal : null,
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('LOSS · ${verdict.word.toUpperCase()}', style: WireType.label().copyWith(color: heroSignal ? w.onSignal : w.ink)),
                  WireHeroNumber(value: lossText, size: 150, color: heroSignal ? w.onSignal : w.ink),
                ],
              ),
            ),
            const WireRule(),
            WireSplitRow(
              children: [
                WireStat(label: 'Sent', value: '${r.sent}', valueSize: 30, padding: const EdgeInsets.fromLTRB(14, 10, 14, 10)),
                WireStat(label: 'Lost', value: '${r.lost}', valueSize: 30, padding: const EdgeInsets.fromLTRB(14, 10, 14, 10)),
              ],
            ),
            const WireRule(),
            WireSplitRow(
              children: [
                WireStat(label: 'Late', value: '${r.late}', valueSize: 30, padding: const EdgeInsets.fromLTRB(14, 10, 14, 10)),
                WireStat(label: 'Avg RTT', value: r.avgRtt == null ? '—' : '${fmtMs(r.avgRtt)} MS', valueSize: 30, padding: const EdgeInsets.fromLTRB(14, 10, 14, 10)),
              ],
            ),
            const WireRule(),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Text(verdict.text, style: WireType.body(12)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: _Timeline(run: r, columns: 24, cellHeight: 10, gap: 2),
            ),
          ],
        ),
        action: s.running
            ? WireButton.bar(label: 'Stop', glyph: '■', variant: WireButtonVariant.inverse, onPressed: n.stop)
            : WireButton.bar(label: 'Start', glyph: '▶', onPressed: _start),
      ),
      desktop: (context) => WireDesktopPage(
        topBar: ToolTargetBar(
          controller: _target,
          running: s.running,
          subtitle: s.address != null && s.address != s.target ? s.address : null,
          runLabel: 'Start',
          onRun: _start,
          onStop: n.stop,
          chips: [
            CycleChip<int>(
              values: const [1, 5, 15, 60],
              value: s.durationMin,
              label: (v) => 'DURATION $v MIN',
              enabled: !s.running,
              onChanged: n.setDuration,
            ),
            CycleChip<int>(
              values: const [1, 2, 5],
              value: s.ratePerSec,
              label: (v) => 'RATE $v/S',
              enabled: !s.running,
              onChanged: n.setRate,
            ),
          ],
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (s.error != null) WireErrorBlock(reason: s.error!, size: 80),
            Container(
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: w.ink, width: kWireBorder))),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: 330,
                      color: heroSignal ? w.signal : null,
                      padding: const EdgeInsets.fromLTRB(32, 20, 24, 12),
                      decoration: null,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('PACKET LOSS', style: WireType.label(12).copyWith(color: heroSignal ? w.onSignal : w.ink)),
                          SizedBox(
                            height: 180,
                            child: Align(
                              alignment: Alignment.bottomLeft,
                              child: WireHeroNumber(value: lossText, size: 200, color: heroSignal ? w.onSignal : w.ink),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const WireVRule(),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          WireSplitRow(
                            children: [
                              WireStat(label: 'Sent', value: '${r.sent}', valueSize: 40),
                              WireStat(label: 'Lost', value: '${r.lost}', valueSize: 40),
                              WireStat(label: 'Late', value: '${r.late}', valueSize: 40),
                              WireStat(label: 'Longest burst', value: '${r.longestBurst}', valueSize: 40),
                            ],
                          ),
                          const WireRule(),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'ELAPSED ${_clock(elapsed)} / ${_clock(Duration(minutes: s.durationMin))}',
                                          style: WireType.label(12),
                                        ),
                                      ),
                                      Text('${(progress * 100).round()}%', style: WireType.label(12)),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  WireProgress(value: progress, height: 18, signal: false),
                                  const SizedBox(height: 10),
                                  Text.rich(
                                    TextSpan(
                                      children: [
                                        TextSpan(text: s.running ? 'Verdict so far: ' : 'Verdict: '),
                                        TextSpan(text: '${verdict.word}. ', style: const TextStyle(fontWeight: FontWeight.w700)),
                                        TextSpan(text: verdict.text),
                                      ],
                                    ),
                                    style: WireType.body(13),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'TIMELINE · 1 CELL = ${_perCell(r.packets.length)} PACKET${_perCell(r.packets.length) == 1 ? '' : 'S'}',
                            style: WireType.label(),
                          ),
                        ),
                        Text('■ OK  ', style: WireType.label()),
                        Text('■ LATE >150MS  ', style: WireType.label().copyWith(color: w.degraded)),
                        Text('■ LOST', style: WireType.label().copyWith(color: w.signal)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (r.packets.isEmpty)
                      Text('Pick a target, duration and rate, then START.', style: WireType.body(13).copyWith(color: w.text3))
                    else
                      _Timeline(run: r, columns: 40, cellHeight: 16, gap: 3),
                  ],
                ),
              ),
            ),
            PanelActions(
              actions: [
                (label: 'Export CSV', primary: false, onTap: r.sent == 0 ? null : _export),
                (label: 'Set alert on loss', primary: false, onTap: s.target.isEmpty ? null : _alert),
                (
                  label: s.compare == null ? 'Compare to 1.1.1.1' : 'Comparing…',
                  primary: false,
                  onTap: s.running && s.compare == null ? n.compareToCloudflare : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Packets per timeline cell so long runs stay readable.
int _perCell(int packets) => math.max(1, (packets / 600).ceil());

class _Timeline extends StatelessWidget {
  const _Timeline({required this.run, required this.columns, required this.cellHeight, required this.gap});
  final LossRun run;
  final int columns;
  final double cellHeight;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final w = context.wire;
    final per = _perCell(run.packets.length);
    final cells = (run.packets.length / per).ceil();
    final colors = <Color>[];
    for (var c = 0; c < cells; c++) {
      var lost = false, late = false, pending = true;
      for (var i = c * per; i < math.min(run.packets.length, (c + 1) * per); i++) {
        final p = run.packets[i];
        if (p != PacketState.pending) pending = false;
        if (p == PacketState.lost) lost = true;
        if (p == PacketState.late) late = true;
      }
      colors.add(lost ? w.signal : late ? w.degraded : pending ? w.mutedRow : w.ink);
    }
    return LayoutBuilder(
      builder: (context, box) {
        final width = (box.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [for (final c in colors) Container(width: width, height: cellHeight, color: c)],
        );
      },
    );
  }
}
