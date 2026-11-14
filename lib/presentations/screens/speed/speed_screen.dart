import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/format.dart';
import '../../../core/widgets/pulse/pulse.dart';
import '../../../providers/network_provider.dart';
import '../../../providers/speed_provider.dart';
import '../../../services/net/speed_test.dart';
import '../../navigation/destinations.dart';
import 'speed_widgets.dart';

/// Engine defaults, for the "6.2 s" phase clock.
final _engine = SpeedTest();

/// 08 Speed test: phase group, wavy circular gauge (log scale), shape stats.
/// Tablet: gauge on the left, Ping/Jitter shapes, upload card and past results
/// in a 300 dp column on the right.
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
      if (!mounted) return;
      final s = ref.read(speedProvider);
      if (!s.hasServer && !s.selecting) ref.read(speedProvider.notifier).autoSelect();
    });
  }

  void _copy(SpeedState s) {
    final text = [
      'Pulse speed test · ${serverLabel(s)}',
      '↓ ${fmtMbps(s.downMbps)} Mbps',
      '↑ ${fmtMbps(s.upMbps)} Mbps',
      'ping ${fmtMs(s.pingMs)} ms',
      'jitter ${fmtMs(s.jitterMs)} ms',
    ].join(' · ');
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Result copied'), duration: Duration(seconds: 2)));
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(speedProvider);
    final n = ref.read(speedProvider.notifier);
    // Server distances need this network's public location.
    ref.watch(networkInfoProvider);
    final compact = context.isCompact;

    final serverChip = _ServerChip(state: s, long: !compact, onTap: () => showSpeedServerSheet(context, ref));

    return LayoutBuilder(
      builder: (context, box) {
        final wide = !compact && box.maxWidth >= 760;
        return PulsePage(
          title: 'Speed test',
          backTo: Routes.tools,
          actions: [
            serverChip,
            if (!compact && s.running)
              PulseButton(label: 'Cancel', icon: PulseIcons.stop, style: PulseButtonStyle.tonal, onPressed: n.cancel),
          ],
          body: wide
              ? _TabletBody(state: s, onCopy: () => _copy(s))
              : _PhoneBody(state: s, onCopy: () => _copy(s), showCancel: compact),
        );
      },
    );
  }
}

class _ServerChip extends StatelessWidget {
  const _ServerChip({required this.state, required this.long, required this.onTap});
  final SpeedState state;
  final bool long;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final s = state;
    final label = [
      serverLabel(s),
      if (long && s.hasServer && s.server.isCloudflare) 'anycast',
      if (long && s.hasServer && !s.server.isCloudflare) 'upload via Cloudflare',
    ].join(' · ');
    return PulseButton(
      label: label,
      icon: PulseIcons.server,
      style: PulseButtonStyle.outlined,
      size: long ? PulseButtonSize.medium : PulseButtonSize.small,
      tooltip: 'Server',
      onPressed: onTap,
    );
  }
}

// ---------------------------------------------------------------------------
// Shared pieces
// ---------------------------------------------------------------------------

class _Phases extends StatelessWidget {
  const _Phases({required this.state, this.long = false});
  final SpeedState state;
  final bool long;

  @override
  Widget build(BuildContext context) {
    final s = state;
    final pingDone = s.pingMs != null && s.phase != SpeedPhase.ping;
    final downDone = s.downMbps != null;
    final upDone = s.upMbps != null;
    return Semantics(
      label: 'Test phases',
      child: PulseButtonGroup<SpeedPhase>(
        selected: s.running ? s.phase : null,
        segments: [
          PulseSegment(
            SpeedPhase.ping,
            'Ping',
            icon: PulseIcons.pulse,
            done: pingDone,
            trailing: pingDone ? '${fmtMs(s.pingMs)}${long ? ' ms' : ''}' : null,
          ),
          PulseSegment(
            SpeedPhase.download,
            'Download',
            icon: PulseIcons.down,
            done: downDone,
            trailing: downDone ? fmtMbps(s.downMbps) : null,
          ),
          PulseSegment(
            SpeedPhase.upload,
            'Upload',
            icon: long || s.phase == SpeedPhase.upload ? PulseIcons.up : null,
            done: upDone,
            trailing: upDone ? fmtMbps(s.upMbps) : null,
          ),
        ],
      ),
    );
  }
}

/// The wavy circular gauge with the live value in its centre, or the pink
/// Start button when idle.
class _Gauge extends ConsumerWidget {
  const _Gauge({required this.state, required this.size});
  final SpeedState state;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = state;
    final c = context.colors;
    final big = size >= 360;
    final idle = s.phase == SpeedPhase.idle || (s.phase == SpeedPhase.done && s.downMbps == null);
    final mbps = switch (s.phase) {
      SpeedPhase.download || SpeedPhase.upload => s.liveMbps,
      SpeedPhase.done => s.downMbps,
      _ => null,
    };
    final Widget centre;
    if (idle) {
      centre = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PulseButton(
            label: 'Start',
            icon: PulseIcons.play,
            size: PulseButtonSize.large,
            onPressed: s.selecting ? null : ref.read(speedProvider.notifier).start,
          ),
          const SizedBox(height: 10),
          Text(
            s.selecting ? 'Finding the fastest server…' : 'Ping, download, then upload',
            style: context.type.bodySmall!.copyWith(color: c.onSurfaceVariant),
          ),
        ],
      );
    } else {
      final ping = s.phase == SpeedPhase.ping;
      final label = switch (s.phase) {
        SpeedPhase.ping => 'Ping',
        SpeedPhase.upload => 'Upload',
        _ => 'Download',
      };
      centre = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: pulseText(big ? 16 : 14, 600).copyWith(color: c.onSurfaceVariant)),
          MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.3)),
            child: PulseLiveValue(
              ping
                  ? (s.pingMs == null ? '…' : fmtMs(s.pingMs))
                  : s.phase == SpeedPhase.done
                  ? fmtMbps(mbps ?? 0)
                  : fmtLiveMbps(mbps ?? 0),
              style: pulseText(big ? 132 : 92, 900, wdth: 125, height: 1, tracking: -.04).copyWith(color: c.onSurface),
            ),
          ),
          Text(ping ? 'ms' : 'Mbps', style: pulseText(big ? 20 : 16, 700).copyWith(color: c.primary)),
        ],
      );
    }
    return Semantics(
      label: idle ? 'Speed gauge, not started' : 'Speed gauge, ${fmtMbps(mbps ?? 0)} megabits per second',
      child: WavyProgress(
        circular: true,
        size: Size(size, size),
        value: speedGaugeValue(mbps),
        child: SizedBox(
          width: size * .62,
          child: FittedBox(fit: BoxFit.scaleDown, child: centre),
        ),
      ),
    );
  }
}

class _PhaseProgress extends StatelessWidget {
  const _PhaseProgress({required this.state, this.scaleNote = false});
  final SpeedState state;
  final bool scaleNote;

  @override
  Widget build(BuildContext context) {
    final s = state;
    final c = context.colors;
    final (String what, String clock) = switch (s.phase) {
      SpeedPhase.ping => ('Measuring ping', '${(s.progress * 10).round()} of 10'),
      SpeedPhase.download => (
        'Measuring download',
        '${(s.progress * _engine.downloadTime.inMilliseconds / 1000).toStringAsFixed(1)} s',
      ),
      SpeedPhase.upload => (
        'Measuring upload',
        '${(s.progress * _engine.uploadTime.inMilliseconds / 1000).toStringAsFixed(1)} s',
      ),
      SpeedPhase.done => ('Finished', ''),
      SpeedPhase.idle => ('Ready', ''),
    };
    final style = context.type.bodySmall!.copyWith(color: c.onSurfaceVariant);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                scaleNote ? '$what · log scale 1–500 Mbps' : what,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: style,
              ),
            ),
            Text(clock, style: style),
          ],
        ),
        const SizedBox(height: 6),
        PulseWavyBar(value: s.progress.clamp(0, .999).toDouble(), semanticLabel: what),
      ],
    );
  }
}

/// "Upload — next": a dashed arch while the upload has not started.
class _PendingArch extends StatelessWidget {
  const _PendingArch({required this.size, required this.label, required this.note});
  final double size;
  final String label, note;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      label: '$label, $note',
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: size,
        child: DashedOutline(
          path: DashedOutline.shape(PulseShape.arch),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(height: size * .08),
                  Text(label, style: pulseText(size * .12, 700).copyWith(color: c.onSurfaceVariant)),
                  Text('—', style: pulseText(size * .28, 900, height: 1).copyWith(color: c.onSurfaceVariant)),
                  Text(note, style: pulseText(size * .11, 700).copyWith(color: c.onSurfaceVariant)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PingShape extends StatelessWidget {
  const _PingShape({required this.state, required this.size});
  final SpeedState state;
  final double size;

  @override
  Widget build(BuildContext context) => PulsePop(
    delay: const Duration(milliseconds: 200),
    child: PulseShapeStat(
      shape: PulseShape.clover4,
      tone: PulseTone.lime,
      label: 'Ping',
      value: fmtMs(state.pingMs),
      unit: 'ms',
      size: size,
      motion: PulseShapeMotion.wobble,
    ),
  );
}

class _JitterShape extends StatelessWidget {
  const _JitterShape({required this.state, required this.size});
  final SpeedState state;
  final double size;

  @override
  Widget build(BuildContext context) => PulsePop(
    delay: const Duration(milliseconds: 300),
    child: PulseShapeStat(
      shape: PulseShape.sunny,
      tone: PulseTone.lavender,
      label: 'Jitter',
      value: fmtMs(state.jitterMs),
      unit: 'ms',
      size: size,
      motion: PulseShapeMotion.spin,
    ),
  );
}

/// Done: ↓ · ↑ · ping · jitter, then Run again / Copy.
class _Summary extends ConsumerWidget {
  const _Summary({required this.state, required this.onCopy});
  final SpeedState state;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = state;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PulseCard(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: Text('Result', style: context.type.titleMedium)),
                  Flexible(
                    child: Text(
                      serverLabel(s),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.type.bodySmall!.copyWith(color: context.colors.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              PulseStatRow(
                stats: [
                  PulseStat('↓ Down', fmtMbps(s.downMbps), unit: 'Mbps'),
                  PulseStat('↑ Up', fmtMbps(s.upMbps), unit: 'Mbps'),
                  PulseStat('Ping', fmtMs(s.pingMs), unit: 'ms'),
                  PulseStat('Jitter', fmtMs(s.jitterMs), unit: 'ms'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: PulseButton(
                label: 'Run again',
                icon: PulseIcons.refresh,
                size: PulseButtonSize.large,
                expand: true,
                onPressed: ref.read(speedProvider.notifier).start,
              ),
            ),
            const SizedBox(width: 8),
            PulseButton(
              label: 'Copy',
              icon: PulseIcons.copy,
              style: PulseButtonStyle.tonal,
              size: PulseButtonSize.large,
              onPressed: onCopy,
            ),
          ],
        ),
      ],
    );
  }
}

class _ErrorBanner extends ConsumerWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context, WidgetRef ref) => PulseErrorBanner(
    title: 'Speed test failed',
    message: message.replaceFirst('Speed test failed: ', ''),
    onRetry: ref.read(speedProvider.notifier).start,
  );
}

class _PastResults extends ConsumerWidget {
  const _PastResults();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(speedHistoryProvider).value ?? const <SpeedResult>[];
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PulseSectionLabel('Past results', padding: EdgeInsets.fromLTRB(4, 6, 0, 8)),
        if (history.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Text(
              'Finished tests show up here.',
              style: context.type.bodyMedium!.copyWith(color: c.onSurfaceVariant),
            ),
          )
        else
          PulseSegmentedList(
            children: [
              for (final h in history.take(5))
                PulseListItem(
                  title: fmtDay(h.at),
                  titleStyle: context.type.titleMedium!.copyWith(fontSize: 15),
                  subtitle: [h.server, if (h.ping != null) '${fmtMs(h.ping)} ms'].join(' · '),
                  trailing: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('${fmtMbps(h.down)} ↓', style: pulseNumber(16).copyWith(color: c.onSurface)),
                      Text('${fmtMbps(h.up)} ↑', style: context.type.bodySmall!.copyWith(color: c.onSurfaceVariant)),
                    ],
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Phone
// ---------------------------------------------------------------------------

class _PhoneBody extends ConsumerWidget {
  const _PhoneBody({required this.state, required this.onCopy, required this.showCancel});
  final SpeedState state;
  final VoidCallback onCopy;
  final bool showCancel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = state;
    final pad = context.pagePadding;
    final done = s.phase == SpeedPhase.done && s.downMbps != null;
    final idle = !s.running && !done;
    final children = <Widget>[
      // Tablets beside the Tools pane use this body too, with room for the full row.
      _Phases(state: s, long: !context.isCompact),
      if (s.error != null) _ErrorBanner(message: s.error!),
      Center(
        child: LayoutBuilder(
          builder: (context, box) => _Gauge(state: s, size: math.min(280, box.maxWidth)),
        ),
      ),
      if (s.running)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: _PhaseProgress(state: s),
        ),
      if (done)
        _Summary(state: s, onCopy: onCopy)
      else
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: LayoutBuilder(
            builder: (context, box) {
              final size = math.min(140.0, (box.maxWidth - 24) / 3);
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _PingShape(state: s, size: size),
                  _JitterShape(state: s, size: size),
                  PulsePop(
                    delay: const Duration(milliseconds: 400),
                    child: s.phase == SpeedPhase.upload && s.downMbps != null
                        ? PulseShapeStat(
                            shape: PulseShape.arch,
                            tone: PulseTone.pink,
                            label: 'Download',
                            value: fmtMbps(s.downMbps),
                            unit: 'Mbps',
                            size: size,
                          )
                        : _PendingArch(size: size, label: 'Upload', note: idle ? 'Mbps' : 'next'),
                  ),
                ],
              );
            },
          ),
        ),
      if (idle || done) const _PastResults(),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(pad, 8, pad, 24),
            children: [
              for (var i = 0; i < children.length; i++)
                Padding(
                  padding: EdgeInsets.only(top: i == 0 ? 0 : 14),
                  child: PulseEntrance(index: i, child: children[i]),
                ),
            ],
          ),
        ),
        if (s.running && showCancel)
          Padding(
            padding: EdgeInsets.fromLTRB(pad, 4, pad, 16),
            child: PulseButton(
              label: 'Cancel test',
              icon: PulseIcons.stop,
              style: PulseButtonStyle.tonal,
              size: PulseButtonSize.large,
              expand: true,
              onPressed: ref.read(speedProvider.notifier).cancel,
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Tablet
// ---------------------------------------------------------------------------

class _TabletBody extends StatelessWidget {
  const _TabletBody({required this.state, required this.onCopy});
  final SpeedState state;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final s = state;
    final done = s.phase == SpeedPhase.done && s.downMbps != null;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(PulseLayout.tabletPadding, 0, PulseLayout.tabletPadding, 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PulseEntrance(child: _Phases(state: s, long: true)),
                if (s.error != null) ...[const SizedBox(height: 14), _ErrorBanner(message: s.error!)],
                const SizedBox(height: 14),
                LayoutBuilder(
                  builder: (context, box) => Center(
                    child: _Gauge(state: s, size: math.min(400, box.maxWidth)),
                  ),
                ),
                const SizedBox(height: 14),
                if (done)
                  PulseEntrance(
                    index: 2,
                    child: _Summary(state: s, onCopy: onCopy),
                  )
                else if (s.running)
                  _PhaseProgress(state: s, scaleNote: true)
                else
                  Text(
                    'Log scale 1–500 Mbps · uploads go to Cloudflare',
                    textAlign: TextAlign.center,
                    style: context.type.bodySmall!.copyWith(color: context.colors.onSurfaceVariant),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          SizedBox(
            width: PulseLayout.pane,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _PingShape(state: s, size: 144),
                    _JitterShape(state: s, size: 144),
                  ],
                ),
                const SizedBox(height: 12),
                PulseEntrance(index: 1, child: _UploadCard(state: s)),
                const SizedBox(height: 12),
                const PulseEntrance(index: 2, child: _PastResults()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Tablet upload card: dashed while pending, live during upload, solid when done.
class _UploadCard extends StatelessWidget {
  const _UploadCard({required this.state});
  final SpeedState state;

  @override
  Widget build(BuildContext context) {
    final s = state;
    final c = context.colors;
    final pending = s.upMbps == null && s.phase != SpeedPhase.upload;
    final value = s.phase == SpeedPhase.upload ? s.liveMbps : s.upMbps;
    final row = Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      child: Row(
        children: [
          PulseIcon(PulseIcons.up, size: 22, color: c.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Upload', style: context.type.titleMedium),
                Text(switch (s.phase) {
                  SpeedPhase.upload => 'Measuring · Cloudflare',
                  SpeedPhase.done when s.upMbps != null => 'Cloudflare',
                  SpeedPhase.idle || SpeedPhase.done => 'Runs after download',
                  _ => 'Starts after download',
                }, style: context.type.bodySmall!.copyWith(color: c.onSurfaceVariant)),
              ],
            ),
          ),
          if (pending)
            Text('—', style: pulseNumber(24).copyWith(color: c.outline))
          else
            PulseNumber(
              s.phase == SpeedPhase.upload ? fmtLiveMbps(value) : fmtMbps(value),
              unit: 'Mbps',
              live: true,
              unitScale: .5,
              style: pulseNumber(24),
            ),
        ],
      ),
    );
    if (!pending) return PulseCard(padding: EdgeInsets.zero, radius: 24, child: row);
    return DashedOutline(path: DashedOutline.rounded(24), child: row);
  }
}
