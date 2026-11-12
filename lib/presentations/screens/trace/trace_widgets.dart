import 'package:material_ui/material_ui.dart';

import '../../../core/format.dart';
import '../../../core/widgets/pulse/pulse.dart';
import '../../../services/net/traceroute.dart';
import 'route_rail.dart';
import 'trace_insights.dart';

/// "LAN" / "ISP" / "SG" pill. Outlined, or filled on the selected row.
class TraceZonePill extends StatelessWidget {
  const TraceZonePill(this.label, {super.key, this.selected = false});
  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? c.onSecondaryContainer : null,
        borderRadius: BorderRadius.circular(12),
        border: selected ? null : Border.all(color: c.outline),
      ),
      child: Text(
        label,
        maxLines: 1,
        style: pulseText(11, 700, wdth: 105).copyWith(color: selected ? c.secondaryContainer : c.onSurfaceVariant),
      ),
    );
  }
}

/// Route rail inside a card with "Route · N timeouts" above it.
class TraceRouteCard extends StatelessWidget {
  const TraceRouteCard({super.key, required this.insights});
  final TraceInsights insights;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = insights.timeoutCount;
    final style = context.type.bodySmall!.copyWith(fontWeight: FontWeight.w600, color: c.onSurfaceVariant);
    return PulseCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text('Route', style: style)),
              if (insights.hops.isNotEmpty)
                Text(t == 0 ? 'No timeouts' : '$t timeout${t == 1 ? '' : 's'}', style: style),
            ],
          ),
          const SizedBox(height: 4),
          TraceRouteRail(insights: insights, background: c.surfaceContainer),
        ],
      ),
    );
  }
}

/// Phone summary: "56 ms to reach" with hop and route pills.
class TraceSummary extends StatelessWidget {
  const TraceSummary({super.key, required this.insights, required this.running});
  final TraceInsights insights;
  final bool running;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final total = insights.total;
    final label = running
        ? 'so far'
        : insights.reached
        ? 'to reach'
        : 'to last reply';
    final route = insights.routeLabel;
    final scaler = MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.3);
    return Semantics(
      label: '${fmtMs(total)} ms $label, ${insights.hops.length} hops${route == null ? '' : ', $route'}',
      liveRegion: running,
      excludeSemantics: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.bottomLeft,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  MediaQuery(
                    data: MediaQuery.of(context).copyWith(textScaler: scaler),
                    child: PulseLiveValue(fmtMs(total), style: context.type.displayMedium),
                  ),
                  const SizedBox(width: 6),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('ms', style: pulseText(15, 700, height: 1.2).copyWith(color: c.onSurface)),
                        Text(label, style: pulseText(15, 500, height: 1.2).copyWith(color: c.onSurfaceVariant)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              PulsePill(
                '${insights.hops.length} hop${insights.hops.length == 1 ? '' : 's'}',
                tone: PulsePillTone.lime,
                height: 34,
              ),
              if (route != null) ...[
                const SizedBox(height: 6),
                PulsePill(route, tone: PulsePillTone.lavender, height: 34),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Tablet "Destination reached" card: total, then hop / route / timeout pills.
class TraceDestinationCard extends StatelessWidget {
  const TraceDestinationCard({super.key, required this.insights, required this.running});
  final TraceInsights insights;
  final bool running;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final title = running
        ? 'Tracing…'
        : insights.reached
        ? 'Destination reached'
        : insights.isEmpty
        ? 'Not run yet'
        : 'Destination not reached';
    final route = insights.routeLabel;
    final t = insights.timeoutCount;
    return PulseCard(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: context.type.labelLarge!.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                PulseLiveValue(fmtMs(insights.total), style: context.type.displayMedium),
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('ms', style: pulseText(16, 700).copyWith(color: c.onSurface)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              PulsePill(
                '${insights.hops.length} hop${insights.hops.length == 1 ? '' : 's'}',
                tone: PulsePillTone.lime,
                height: 32,
              ),
              if (route != null) PulsePill(route, tone: PulsePillTone.lavender, height: 32),
              if (t > 0) PulsePill('$t timeout${t == 1 ? '' : 's'}', tone: PulsePillTone.outline, height: 32),
            ],
          ),
        ],
      ),
    );
  }
}

/// primaryContainer card explaining the biggest jump in plain language.
class TraceJumpCard extends StatelessWidget {
  const TraceJumpCard({super.key, required this.insights});
  final TraceInsights insights;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = insights.jumpSentence;
    if (s == null) return const SizedBox.shrink();
    final body = context.type.bodyMedium!.copyWith(color: c.onPrimaryContainer, height: 1.45);
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(color: c.primaryContainer, borderRadius: BorderRadius.circular(28)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PulseIcon(PulseIcons.info, size: 20, color: c.onPrimaryContainer),
              const SizedBox(width: 8),
              Text('Biggest jump', style: pulseText(15, 800).copyWith(color: c.onPrimaryContainer)),
            ],
          ),
          const SizedBox(height: 6),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: s.before),
                TextSpan(
                  text: s.bold,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                TextSpan(text: s.after),
              ],
            ),
            style: body,
          ),
        ],
      ),
    );
  }
}

/// Lead for a highlight row: a number inside a shape (or a dashed ring).
class _HighlightLead extends StatelessWidget {
  const _HighlightLead(this.h);
  final TraceHighlight h;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    const size = 38.0;
    Text label(Color color) =>
        Text(h.lead, maxLines: 1, style: pulseText(h.lead.length > 3 ? 11 : 13, 800, wdth: 105).copyWith(color: color));
    if (h.noReply) return DashedRing(size: size, color: c.outline, child: label(c.onSurfaceVariant));
    final (PulseShape shape, Color fill, Color on, Duration? spin) = switch (h.kind) {
      TraceHighlightKind.firstHop => (PulseShape.circle, c.tertiaryContainer, c.onTertiaryContainer, null),
      TraceHighlightKind.spike => (PulseShape.arch, c.secondaryContainer, c.onSecondaryContainer, null),
      TraceHighlightKind.timeouts => (PulseShape.circle, c.surfaceContainerHigh, c.onSurfaceVariant, null),
      TraceHighlightKind.jump => (PulseShape.diamond, c.primaryContainer, c.onPrimaryContainer, null),
      TraceHighlightKind.destination => (
        PulseShape.cookie9,
        PulseTone.pink.fill(context),
        PulseTone.pink.on(context),
        PulseMotion.smallSpin,
      ),
    };
    return ExcludeSemantics(
      child: PulseShapeBox(
        shape: shape,
        color: fill,
        size: size + (shape == PulseShape.diamond || shape == PulseShape.cookie9 ? 4 : 0),
        spin: spin,
        child: label(on),
      ),
    );
  }
}

/// Phone "Highlights": first hop, local spike, timeouts, biggest jump and the
/// destination. While running, a "Probing hop N" row closes the list.
class TraceHighlights extends StatelessWidget {
  const TraceHighlights({super.key, required this.insights, this.running = false, this.maxHops = 30});
  final TraceInsights insights;
  final bool running;
  final int maxHops;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final items = insights.highlights;
    return PulseSegmentedList(
      children: [
        for (final h in items)
          PulseListItem(
            minHeight: 54,
            padding: const EdgeInsets.fromLTRB(10, 6, 16, 6),
            leading: SizedBox(width: 42, child: Center(child: _HighlightLead(h))),
            title: h.title,
            titleStyle: context.type.titleMedium!.copyWith(fontSize: 15),
            subtitle: h.subtitle,
            trailing: h.pill != null
                ? PulsePill(h.pill!, tone: PulsePillTone.pink, height: 30)
                : h.ms != null
                ? PulseNumber(fmtMs(h.ms), unit: 'ms', unitScale: .6, style: pulseNumber(18))
                : Text('—', style: pulseNumber(18).copyWith(color: c.outline)),
          ),
        if (running)
          PulseListItem(
            minHeight: 54,
            padding: const EdgeInsets.fromLTRB(10, 6, 16, 6),
            leading: const SizedBox(
              width: 42,
              child: Center(
                child: PulseShapeBadge(
                  shape: PulseShape.cookie9,
                  tone: PulseTone.lavender,
                  size: 30,
                  spin: PulseMotion.smallSpin,
                ),
              ),
            ),
            title: 'Probing hop ${insights.probingHop}…',
            titleStyle: context.type.titleMedium!.copyWith(fontSize: 15),
            subtitle: 'Up to $maxHops hops',
          ),
      ],
    );
  }
}

/// The full hop list as a segmented list. Consecutive timeouts are grouped
/// ("No reply · 09–10"); with [collapse], long transit runs fold into one
/// expandable row ("Transit · hops 11–20"). The destination row is selected.
class TraceHopList extends StatefulWidget {
  const TraceHopList({super.key, required this.insights, this.running = false, this.collapse = true});
  final TraceInsights insights;
  final bool running;
  final bool collapse;

  @override
  State<TraceHopList> createState() => _TraceHopListState();
}

class _TraceHopListState extends State<TraceHopList> {
  final _expanded = <int>{};

  static const _transitMin = 5;

  @override
  Widget build(BuildContext context) {
    final ins = widget.insights;
    final hops = ins.hops;
    final rows = <Widget>[];
    final last = hops.length - 1;
    final jump = ins.jump;
    var i = 0;
    while (i < hops.length) {
      final h = hops[i];
      if (!h.done && h.ip == null && h.avg == null) {
        i++; // still probing: the "Probing hop" row stands in for it
        continue;
      }
      if (h.timedOut) {
        var j = i;
        while (j + 1 < hops.length && hops[j + 1].timedOut) {
          j++;
        }
        rows.add(_timeoutRow(context, hops[i], hops[j]));
        i = j + 1;
        continue;
      }
      // A run of replying public hops in the same zone, not the destination.
      if (widget.collapse && ins.finished && ins.zones[i].isPublic && h.avg != null) {
        var j = i;
        while (j + 1 < last &&
            !hops[j + 1].timedOut &&
            hops[j + 1].avg != null &&
            ins.zones[j + 1] == ins.zones[i] &&
            hops[j + 1] != ins.spike) {
          j++;
        }
        if (j - i + 1 >= _transitMin) {
          final run = hops.sublist(i, j + 1);
          final open = _expanded.contains(h.n);
          final jumpHere = jump != null && run.any((x) => x.n == jump.to);
          rows.add(_transitRow(context, run, open, jumpHere ? '+${fmtMs(jump.addMs)} ms jump' : null));
          if (open) {
            for (final x in run) {
              rows.add(_hopRow(context, x, ins.zones[hops.indexOf(x)]));
            }
          }
          i = j + 1;
          continue;
        }
      }
      rows.add(
        ins.reached && i == last ? _destinationRow(context, h, ins.zones[i]) : _hopRow(context, h, ins.zones[i]),
      );
      i++;
    }
    if (widget.running) rows.add(_probingRow(context, ins.probingHop));
    return PulseSegmentedList(children: rows);
  }

  Widget _lead(BuildContext context, int n, Widget mark) => SizedBox(
    width: 48,
    child: Row(
      children: [
        SizedBox(
          width: 28,
          child: Text(
            hopNo(n),
            style: context.type.labelLarge!.copyWith(fontSize: 13, color: context.colors.onSurfaceVariant),
          ),
        ),
        SizedBox(width: 20, child: Center(child: mark)),
      ],
    ),
  );

  Widget _dot(Color color) => Container(
    width: 12,
    height: 12,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );

  Widget _rtt(BuildContext context, double? ms, {double size = 18}) => SizedBox(
    width: 52,
    child: Align(
      alignment: Alignment.centerRight,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(fmtMs(ms), style: pulseNumber(size)),
      ),
    ),
  );

  Widget _trailing(BuildContext context, TraceZone zone, double? ms, {bool selected = false}) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (zone.label != null) TraceZonePill(zone.label!, selected: selected),
      _rtt(context, ms, size: selected ? 19 : 18),
    ],
  );

  Widget _hopRow(BuildContext context, TraceHop h, TraceZone zone) {
    final title = h.host ?? (h.n == 1 && zone.kind == TraceZoneKind.lan ? 'Router' : h.ip ?? '…');
    final sub = [if (h.ip != null && h.ip != title) h.ip!, probesText(h)].where((s) => s.isNotEmpty).join(' · ');
    return Semantics(
      label:
          'Hop ${h.n}, $title, ${h.avg == null ? 'probing' : '${fmtMs(h.avg)} ms'}${zone.label == null ? '' : ', ${zone.label}'}',
      excludeSemantics: true,
      child: PulseListItem(
        minHeight: 48,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        leading: _lead(
          context,
          h.n,
          h.avg == null
              ? DashedRing(size: 12, strokeWidth: 1.5, color: context.colors.outlineVariant)
              : _dot(context.pulse.latencyColor(h.avg)),
        ),
        title: title,
        titleStyle: context.type.titleMedium!.copyWith(fontSize: 15),
        subtitle: sub.isEmpty ? null : sub,
        trailing: _trailing(context, zone, h.avg),
      ),
    );
  }

  Widget _destinationRow(BuildContext context, TraceHop h, TraceZone zone) {
    final ins = widget.insights;
    final title = ins.target.isEmpty ? (h.host ?? h.ip ?? 'Destination') : ins.target;
    return Semantics(
      label: 'Destination, hop ${h.n}, $title, ${fmtMs(h.avg)} ms',
      excludeSemantics: true,
      child: PulseListItem(
        selected: true,
        minHeight: 54,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        leading: _lead(
          context,
          h.n,
          PulseShapeBox(
            shape: PulseShape.cookie9,
            color: PulseTone.pink.fill(context),
            size: 18,
            spin: PulseMotion.smallSpin,
          ),
        ),
        title: title,
        subtitle: h.ip == null || h.ip == title ? null : h.ip,
        trailing: _trailing(context, zone, h.avg, selected: true),
      ),
    );
  }

  Widget _timeoutRow(BuildContext context, TraceHop a, TraceHop b) {
    final c = context.colors;
    final range = a.n == b.n ? hopNo(a.n) : '${hopNo(a.n)}–${hopNo(b.n)}';
    return Semantics(
      label: 'No reply from hop${a.n == b.n ? '' : 's'} $range',
      excludeSemantics: true,
      child: PulseListItem(
        minHeight: 46,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        leading: _lead(context, a.n, DashedRing(size: 12, strokeWidth: 1.6, color: c.outline)),
        title: 'No reply · $range',
        titleStyle: context.type.titleMedium!.copyWith(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: c.onSurfaceVariant,
        ),
        trailing: Text('probes timed out', style: context.type.bodySmall!.copyWith(color: c.onSurfaceVariant)),
      ),
    );
  }

  Widget _transitRow(BuildContext context, List<TraceHop> run, bool open, String? jumpPill) {
    final c = context.colors;
    final first = run.first, lastHop = run.last;
    return Semantics(
      button: true,
      expanded: open,
      label: 'Transit, hops ${first.n} to ${lastHop.n}${jumpPill == null ? '' : ', $jumpPill'}',
      excludeSemantics: true,
      child: PulseListItem(
        minHeight: 48,
        padding: const EdgeInsets.fromLTRB(16, 4, 12, 4),
        onTap: () => setState(() => open ? _expanded.remove(first.n) : _expanded.add(first.n)),
        leading: _lead(context, first.n, _dot(context.pulse.latencyColor(first.avg))),
        title: 'Transit · hops ${hopNo(first.n)}–${hopNo(lastHop.n)}',
        titleStyle: context.type.titleMedium!.copyWith(fontSize: 15),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (jumpPill != null) PulsePill(jumpPill, tone: PulsePillTone.pink, height: 28),
            const SizedBox(width: 8),
            AnimatedRotation(
              turns: open ? .5 : 0,
              duration: PulseMotion.shapeMorph,
              curve: PulseMotion.spring,
              child: PulseIcon(PulseIcons.chevD, size: 20, color: c.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _probingRow(BuildContext context, int n) => PulseListItem(
    minHeight: 46,
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
    leading: _lead(
      context,
      n,
      const PulseShapeBadge(shape: PulseShape.cookie9, tone: PulseTone.lavender, size: 16, spin: PulseMotion.smallSpin),
    ),
    title: 'Probing hop ${hopNo(n)}…',
    titleStyle: context.type.titleMedium!.copyWith(
      fontSize: 15,
      fontWeight: FontWeight.w500,
      color: context.colors.onSurfaceVariant,
    ),
  );
}
