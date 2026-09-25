import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/format.dart';
import '../../../core/widgets/wire/wire.dart';
import '../../../core/widgets/wire/wire_page.dart';
import '../../../providers/network_provider.dart';
import '../../../providers/speed_provider.dart';
import '../../../services/net/speed_test.dart';
import '../tools/tool_widgets.dart';

/// 10 — Speed test.
class SpeedScreen extends ConsumerStatefulWidget {
  const SpeedScreen({super.key});

  @override
  ConsumerState<SpeedScreen> createState() => _SpeedScreenState();
}

class _SpeedScreenState extends ConsumerState<SpeedScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!ref.read(speedProvider).hasServer) ref.read(speedProvider.notifier).autoSelect();
    });
  }

  String _mbps(double? v) => v == null
      ? '—'
      : v >= 100
      ? v.toStringAsFixed(0)
      : v.toStringAsFixed(1);

  Future<void> _change() async {
    final n = ref.read(speedProvider.notifier);
    final picked = await showDialog<SpeedServer>(
      context: context,
      builder: (context) {
        final w = context.wire;
        return Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  color: w.ink,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  child: Text('SERVER', style: WireType.title(26).copyWith(color: w.background)),
                ),
                for (final s in kSpeedServers)
                  WireRow(
                    onTap: () => Navigator.of(context).pop(s),
                    child: Row(
                      children: [
                        Expanded(child: Text('${s.name} · ${s.location}', style: WireType.data(14))),
                        Text(
                          n.distanceTo(s) == null
                              ? (s.isCloudflare ? 'ANYCAST' : '')
                              : '${n.distanceTo(s)!.round()} KM',
                          style: WireType.label(),
                        ),
                      ],
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Uploads always go to Cloudflare — Hetzner servers are download-only.',
                    style: WireType.body(12).copyWith(color: w.text2),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (picked != null) n.choose(picked);
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(speedProvider);
    final n = ref.read(speedProvider.notifier);
    final w = context.wire;
    // Distance needs this network's public location.
    ref.watch(networkInfoProvider);
    final dist = s.hasServer ? n.distanceTo(s.server) : null;
    final serverName = !s.hasServer
        ? (s.selecting ? 'Selecting…' : '—')
        : s.server.isCloudflare
        ? 'Cloudflare${s.colo == null ? '' : ' · ${s.colo}'}'
        : '${s.server.name} · ${s.server.location}';
    final serverMeta = [
      if (dist != null) '${dist.round()} km',
      if (s.server.isCloudflare) 'anycast',
      if (s.autoSelected) 'auto-selected',
      if (!s.server.isCloudflare && s.hasServer) 'upload via Cloudflare',
    ].join(' · ');
    final liveLabel = switch (s.phase) {
      SpeedPhase.ping => 'PING · MEASURING',
      SpeedPhase.download => 'DOWNLOAD · LIVE',
      SpeedPhase.upload => 'UPLOAD · LIVE',
      SpeedPhase.done => 'DOWNLOAD · RESULT',
      SpeedPhase.idle => 'READY',
    };
    final heroValue = switch (s.phase) {
      SpeedPhase.download || SpeedPhase.upload => _mbps(s.liveMbps),
      SpeedPhase.done => _mbps(s.downMbps),
      SpeedPhase.ping => s.pingMs == null ? '…' : fmtMs(s.pingMs),
      SpeedPhase.idle => '—',
    };
    final heroUnit = s.phase == SpeedPhase.ping ? 'ms' : 'mbps';
    final gaugeValue = s.phase == SpeedPhase.done ? (s.downMbps ?? 0) : (s.liveMbps ?? 0);

    Widget steps() => _Steps(phase: s.phase);

    Widget chart({int slots = 48, double pad = 20}) => WireBarChart(
      bars: [for (final x in s.samples) WireBar(x.mbps, color: x.upload ? w.signal : w.chartBar)],
      slots: slots,
      gridStep: 30,
      padding: EdgeInsets.fromLTRB(pad, 16, pad, 0),
    );

    final action = s.running
        ? WireButton.bar(label: 'Cancel', glyph: '■', variant: WireButtonVariant.outline, onPressed: n.cancel)
        : WireButton.bar(label: s.phase == SpeedPhase.done ? 'Test again' : 'Start', glyph: '▶', onPressed: n.start);

    return WireAdaptive(
      mobile: (context) => WireMobilePage(
        header: WireMobileHeader(
          title: 'Speed test',
          onBack: mobileBack(context),
          trailing: Text(
            s.phase == SpeedPhase.idle ? '' : s.phase.name.toUpperCase(),
            style: WireType.label(12).copyWith(color: w.signal),
          ),
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            WireRow(
              onTap: s.running ? null : _change,
              divider: kWireBorder,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: serverName,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    if (serverMeta.isNotEmpty) TextSpan(text: ' · $serverMeta'),
                  ],
                ),
                style: WireType.body(12),
              ),
            ),
            if (s.error != null) WireErrorBlock(reason: s.error!, size: 56),
            Container(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
              decoration: BoxDecoration(
                color: s.running ? w.signal : null,
                border: Border(
                  bottom: BorderSide(color: w.ink, width: kWireBorder),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(liveLabel, style: WireType.label().copyWith(color: s.running ? w.onSignal : w.ink)),
                  WireHeroNumber(value: heroValue, size: 150, color: s.running ? w.onSignal : w.ink, unit: null),
                  Text(
                    heroUnit.toUpperCase(),
                    style: WireType.data(14).copyWith(color: s.running ? w.onSignal : w.ink),
                  ),
                ],
              ),
            ),
            Container(
              height: 46,
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: w.ink, width: kWireBorder),
                ),
              ),
              child: _Gauge(value: gaugeValue, segments: 20, gap: 2),
            ),
            Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: w.ink, width: kWireBorder),
                ),
              ),
              child: WireSplitRow(
                children: [
                  WireStat(
                    label: 'Download',
                    value: _mbps(s.downMbps),
                    valueSize: 32,
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                  ),
                  WireStat(
                    label: 'Ping',
                    value: s.pingMs == null ? '—' : '${fmtMs(s.pingMs)} MS',
                    valueSize: 32,
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                  ),
                ],
              ),
            ),
            Expanded(child: chart(slots: 30, pad: 14)),
          ],
        ),
        action: action,
      ),
      desktop: (context) => WireDesktopPage(
        panelWidth: 340,
        topBar: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Text('SERVER>', style: WireType.label(12)),
                    const SizedBox(width: 16),
                    Flexible(
                      child: Text(serverName, maxLines: 1, overflow: TextOverflow.ellipsis, style: WireType.data(20)),
                    ),
                    const SizedBox(width: 16),
                    Flexible(
                      child: Text(
                        serverMeta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: WireType.body(13).copyWith(color: w.text3),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const WireVRule(),
            WireTopChip(label: 'CHANGE', onTap: s.running ? null : _change),
            if (s.running)
              WireButton(
                label: 'Cancel',
                glyph: '■',
                variant: WireButtonVariant.inverse,
                bordered: false,
                fontSize: 17,
                height: WireLayout.topBar,
                padding: const EdgeInsets.symmetric(horizontal: 28),
                onPressed: n.cancel,
              )
            else
              WireButton(
                label: s.phase == SpeedPhase.done ? 'Test again' : 'Start',
                glyph: '▶',
                variant: WireButtonVariant.primary,
                bordered: false,
                fontSize: 17,
                height: WireLayout.topBar,
                padding: const EdgeInsets.symmetric(horizontal: 28),
                onPressed: s.selecting ? null : n.start,
              ),
          ],
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            steps(),
            if (s.error != null) WireErrorBlock(reason: s.error!, size: 72, onRetry: n.start),
            Container(
              padding: const EdgeInsets.fromLTRB(28, 20, 28, 20),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: w.ink, width: kWireBorder),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(liveLabel, style: WireType.label(12)),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 160,
                    child: Align(
                      alignment: Alignment.bottomLeft,
                      child: WireHeroNumber(value: heroValue, unit: heroUnit, size: 180),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(height: 28, child: _Gauge(value: gaugeValue, segments: 40, gap: 3)),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      for (final l in const ['0', '50', '100', '250', '500+'])
                        Text(l, style: WireType.body(11).copyWith(color: w.text2, height: 1.2)),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(child: chart()),
          ],
        ),
        panel: _SpeedPanel(state: s),
      ),
    );
  }
}

class _Steps extends StatelessWidget {
  const _Steps({required this.phase});
  final SpeedPhase phase;

  @override
  Widget build(BuildContext context) {
    final w = context.wire;
    const steps = [
      (SpeedPhase.ping, '1 PING'),
      (SpeedPhase.download, '2 DOWNLOAD'),
      (SpeedPhase.upload, '3 UPLOAD'),
      (SpeedPhase.done, '4 RESULT'),
    ];
    final current = phase.index;
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: w.ink, width: kWireBorder),
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < steps.length; i++) ...[
              if (i > 0) const WireVRule(),
              Expanded(
                child: Builder(
                  builder: (context) {
                    final idx = steps[i].$1.index;
                    final done = phase != SpeedPhase.idle && (idx < current || phase == SpeedPhase.done);
                    final active = idx == current && phase != SpeedPhase.done && phase != SpeedPhase.idle;
                    final bg = done
                        ? w.ink
                        : active
                        ? w.signal
                        : null;
                    final fg = done
                        ? w.background
                        : active
                        ? w.onSignal
                        : w.ink;
                    return Container(
                      color: bg,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      alignment: Alignment.center,
                      child: Text(
                        '${steps[i].$2}${done
                            ? ' ✓'
                            : active
                            ? '…'
                            : ''}',
                        style: WireType.label(12).copyWith(color: fg),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Gauge extends StatelessWidget {
  const _Gauge({required this.value, required this.segments, required this.gap});
  final double value;
  final int segments;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final w = context.wire;
    final filled = (gaugeFraction(value) * segments).round();
    return WireStatusStrip(
      colors: [for (var i = 0; i < segments; i++) i < filled ? w.ink : Colors.transparent],
      gap: gap,
      height: double.infinity,
      borderColor: w.ink,
    );
  }
}

class _SpeedPanel extends ConsumerWidget {
  const _SpeedPanel({required this.state});
  final SpeedState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final w = context.wire;
    final s = state;
    final history = ref.watch(speedHistoryProvider).value ?? const [];
    String mb(double? v) => v == null
        ? '—'
        : v >= 100
        ? v.toStringAsFixed(0)
        : v.toStringAsFixed(1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('DOWNLOAD', style: WireType.label()),
              Text(mb(s.downMbps), style: WireType.display(60, width: 65, height: 0.95)),
              Text('MBPS', style: WireType.label()),
            ],
          ),
        ),
        const WireRule(),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('UPLOAD', style: WireType.label()),
              Text(mb(s.upMbps), style: WireType.display(44, width: 65, height: 0.95)),
              Text('MBPS', style: WireType.label()),
            ],
          ),
        ),
        const WireRule(),
        WireSplitRow(
          children: [
            WireStat(
              label: 'Ping',
              value: s.pingMs == null ? '—' : '${fmtMs(s.pingMs)} MS',
              valueSize: 32,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            ),
            WireStat(
              label: 'Jitter',
              value: s.jitterMs == null ? '—' : '${fmtMs(s.jitterMs)} MS',
              valueSize: 32,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            ),
          ],
        ),
        const WireRule(),
        const WireSectionBar('Past results'),
        Expanded(
          child: history.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text('Finished tests land here.', style: WireType.body(13).copyWith(color: w.text3)),
                )
              : ListView(
                  children: [
                    for (final h in history)
                      WireRow(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        child: Row(
                          children: [
                            Expanded(child: Text(fmtWhen(h.at), style: WireType.body(12))),
                            Text('↓${mb(h.down)}', style: WireType.data(13)),
                            const SizedBox(width: 14),
                            Text('↑${mb(h.up)}', style: WireType.data(13)),
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
