import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/format.dart';
import '../../../core/widgets/pulse/pulse.dart';
import '../../../data/models/app_settings.dart';
import '../../../data/models/ping_models.dart';
import '../../../providers/ping_provider.dart';
import '../../navigation/destinations.dart';

// ---------------------------------------------------------------------------
// Session helpers
// ---------------------------------------------------------------------------

/// What a host card / row shows about a session.
enum HostState { resolving, live, down, failed, paused, done }

/// The last few probes all failed (or the host is unreachable).
bool isDown(PingSession s) {
  if (s.unreachable) return true;
  if (s.replies.length < 3) return false;
  return s.replies.reversed.take(3).every((r) => !r.received);
}

HostState hostState(PingSession s) {
  if (s.error != null) return HostState.failed;
  if (s.resolving) return HostState.resolving;
  if (!s.running) {
    final perTick = s.params.ipVersion == IpVersionPref.both ? 2 : 1;
    final finished = s.params.count > 0 && s.stats.sent >= s.params.count * perTick;
    return finished ? HostState.done : HostState.paused;
  }
  return isDown(s) ? HostState.down : HostState.live;
}

/// Time since the last reply (or since the start when none came back).
Duration silentFor(PingSession s) {
  DateTime? at;
  for (final r in s.replies.reversed) {
    if (r.received) {
      at = r.at;
      break;
    }
  }
  final end = s.running ? DateTime.now() : (s.endedAt ?? DateTime.now());
  final d = end.difference(at ?? s.startedAt);
  return d.isNegative ? Duration.zero : d;
}

/// "30 s", "4 min", "2 h".
String fmtSpan(Duration d) {
  if (d.inSeconds < 60) return '${d.inSeconds} s';
  if (d.inMinutes < 60) return '${d.inMinutes} min';
  return '${d.inHours} h';
}

String noReplyText(PingSession s) => 'No reply for ${fmtSpan(silentFor(s))}';

/// Latest RTT, or null when the last probe got no reply.
double? lastRtt(PingSession s) {
  final last = s.last;
  if (last == null || !last.received) return null;
  return last.rttMs;
}

/// The live value: latest RTT, "—" for no reply, "…" while resolving.
({String value, String? unit}) heroValue(PingSession s) {
  if (s.resolving) return (value: '…', unit: null);
  final rtt = lastRtt(s);
  if (rtt == null) return (value: '—', unit: null);
  return (value: fmtMs(rtt), unit: 'ms');
}

/// The newest [n] replies as chart values (null = lost).
List<double?> chartValues(PingSession s, int n) {
  final r = s.replies.length > n ? s.replies.sublist(s.replies.length - n) : s.replies;
  return [for (final x in r) x.received ? x.rttMs : null];
}

/// "1 s", "0.5 s".
String intervalLabel(int ms) => ms % 1000 == 0 ? '${ms ~/ 1000} s' : '${(ms / 1000).toStringAsFixed(1)} s';

String ipVersionLabel(IpVersionPref v) => switch (v) {
  IpVersionPref.auto => 'Auto',
  IpVersionPref.ipv4 => 'IPv4',
  IpVersionPref.ipv6 => 'IPv6',
  IpVersionPref.both => 'IPv4 + IPv6',
};

/// "Every 1 s · 56 B" (+ count when limited).
String paramsShort(PingParams p) =>
    ['Every ${intervalLabel(p.intervalMs)}', '${p.packetSize} B', if (p.count > 0) '${p.count} pings'].join(' · ');

/// Subtitle under a host's name: its address, loss or why it is quiet.
({String text, Color color}) hostSubtitle(BuildContext context, PingSession s) {
  final c = context.colors;
  final addr = s.name?.isNotEmpty == true ? s.host : (s.describe ?? 'Every ${intervalLabel(s.params.intervalMs)}');
  return switch (hostState(s)) {
    HostState.failed => (text: 'Lookup failed · ${s.host}', color: c.error),
    HostState.resolving => (text: 'Resolving ${s.host}…', color: c.onSurfaceVariant),
    HostState.down => (text: noReplyText(s), color: c.error),
    HostState.paused => (text: 'Paused · $addr', color: c.onSurfaceVariant),
    HostState.done => (text: 'Done · ${fmtCount(s.stats.sent)} sent · $addr', color: c.onSurfaceVariant),
    HostState.live when s.stats.lost > 0 => (
      text: '${fmtPct(s.stats.lossPct)} loss · $addr',
      color: context.pulse.latSlow,
    ),
    HostState.live => (text: addr, color: c.onSurfaceVariant),
  };
}

/// Opens Ping detail for [s] and makes it the focused (hero) host.
void openPingDetail(BuildContext context, WidgetRef ref, PingSession s) {
  ref.read(pingBoardProvider.notifier).focus(s.id);
  context.go('${Routes.pingDetail}?id=${Uri.encodeQueryComponent(s.id)}');
}

/// Restarts [s] (optionally with new settings) and keeps Ping detail on it.
Future<String?> restartHost(
  BuildContext context,
  WidgetRef ref,
  PingSession s, {
  String? host,
  String? name,
  PingParams? params,
  bool followDetail = false,
}) async {
  final id = await ref.read(pingBoardProvider.notifier).restart(s.id, host: host, name: name, params: params);
  if (!context.mounted) return id;
  if (id == null) {
    showPingLimit(context);
  } else if (followDetail) {
    context.go('${Routes.pingDetail}?id=${Uri.encodeQueryComponent(id)}');
  }
  return id;
}

/// Restarts every host (or only the stopped ones) in place, optionally with
/// new [params], and keeps the same host focused.
Future<void> restartAll(BuildContext context, WidgetRef ref, {PingParams? params, bool onlyStopped = false}) async {
  final n = ref.read(pingBoardProvider.notifier);
  final board = ref.read(pingBoardProvider);
  final focusedId = board.focused?.id;
  String? newFocus;
  for (final s in [...board.sessions]) {
    if (onlyStopped && s.running) continue;
    final id = await n.restart(s.id, params: params);
    if (id == null) {
      if (context.mounted) showPingLimit(context);
      break;
    }
    if (s.id == focusedId) newFocus = id;
  }
  if (newFocus != null) n.focus(newFocus);
}

/// Resumes every stopped host; stops every running one.
Future<void> toggleAll(BuildContext context, WidgetRef ref) async {
  if (ref.read(pingBoardProvider).liveCount > 0) {
    await ref.read(pingBoardProvider.notifier).stopAll();
  } else {
    await restartAll(context, ref, onlyStopped: true);
  }
}

void showPingLimit(BuildContext context) {
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(const SnackBar(content: Text('At most $kMaxLivePings live pings at once. Stop one first.')));
}

/// Plain-text summary for Copy / Share.
String sessionSummary(PingSession s) {
  final st = s.stats;
  return [
    'Ping ${s.title}${s.name?.isNotEmpty == true ? ' (${s.host})' : ''}',
    if (s.describe != null) 'Address: ${s.describe}',
    'Sent ${st.sent} · received ${st.received} · loss ${fmtPct(st.lossPct)}',
    'RTT min ${fmtMs(st.min)} / avg ${fmtMs(st.avg)} / max ${fmtMs(st.max)} ms · jitter ${fmtMs(st.jitter)} ms',
    '${paramsShort(s.params)} · timeout ${s.params.timeoutSec} s · ${ipVersionLabel(s.params.ipVersion)}',
    'Started ${fmtWhen(s.startedAt).toLowerCase()}',
  ].join('\n');
}

// ---------------------------------------------------------------------------
// Badges
// ---------------------------------------------------------------------------

bool _isPrivate(String h) {
  if (h.startsWith('10.') || h.startsWith('192.168.') || h.startsWith('169.254.') || h == 'localhost') return true;
  if (h.startsWith('127.') || h.startsWith('fe80') || h.startsWith('fd')) return true;
  final m = RegExp(r'^172\.(\d+)\.').firstMatch(h);
  if (m != null) {
    final b = int.parse(m.group(1)!);
    return b >= 16 && b <= 31;
  }
  return h.endsWith('.local') || h.endsWith('.lan');
}

/// Lead badge for a host (kit: router = circle tertiaryContainer, Cloudflare =
/// arch secondaryContainer, GitHub = cookie9 primaryContainer, Google DNS =
/// pink cookie9, Google = lime clover).
class HostBadge extends StatelessWidget {
  const HostBadge({super.key, required this.host, this.name, this.gateway, this.size = 40});
  final String host;

  /// The user's label also picks the badge ("Cloudflare", "GitHub").
  final String? name;
  final String? gateway;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final h = host.toLowerCase();
    final k = '$h ${name ?? ''}'.toLowerCase();
    Widget container(PulseShape shape, PulseIcons icon, Color bg, Color fg) =>
        PulseContainerBadge(shape: shape, icon: icon, color: bg, onColor: fg, size: size);
    if (gateway != null && h == gateway!.toLowerCase()) {
      return container(PulseShape.circle, PulseIcons.router, c.tertiaryContainer, c.onTertiaryContainer);
    }
    if (h == '8.8.8.8' || h == '8.8.4.4' || h.startsWith('2001:4860:4860') || k.contains('google dns')) {
      return PulseShapeBadge(shape: PulseShape.cookie9, tone: PulseTone.pink, icon: PulseIcons.globe, size: size);
    }
    if (k.contains('cloudflare') || h == '1.1.1.1' || h == '1.0.0.1' || h.startsWith('2606:4700')) {
      return container(PulseShape.arch, PulseIcons.cloud, c.secondaryContainer, c.onSecondaryContainer);
    }
    if (k.contains('github') || k.contains('gitlab')) {
      return container(PulseShape.cookie9, PulseIcons.code, c.primaryContainer, c.onPrimaryContainer);
    }
    if (k.contains('google') || k.contains('youtube')) {
      return PulseShapeBadge(shape: PulseShape.clover4, tone: PulseTone.lime, icon: PulseIcons.search, size: size);
    }
    if (k.contains('amazonaws') || k.contains('azure') || k.contains('aws')) {
      return container(PulseShape.arch, PulseIcons.server, c.secondaryContainer, c.onSecondaryContainer);
    }
    if (_isPrivate(h)) {
      return container(PulseShape.square, PulseIcons.laptop, c.surfaceContainerHighest, c.onSurfaceVariant);
    }
    return container(PulseShape.cookie9, PulseIcons.globe, c.primaryContainer, c.onPrimaryContainer);
  }
}

/// Small spinning cookie9 showing host health: latFast (no loss), latSlow
/// (loss), error (down), outline (paused).
class HostStatusCookie extends StatelessWidget {
  const HostStatusCookie({super.key, required this.session, this.size = 18});
  final PingSession session;
  final double size;

  @override
  Widget build(BuildContext context) {
    final state = hostState(session);
    final color = switch (state) {
      HostState.down || HostState.failed => context.colors.error,
      HostState.paused || HostState.done || HostState.resolving => context.colors.outline,
      HostState.live => session.stats.lost > 0 ? context.pulse.latSlow : context.pulse.latFast,
    };
    final label = switch (state) {
      HostState.down || HostState.failed => 'Down',
      HostState.paused => 'Paused',
      HostState.done => 'Done',
      HostState.resolving => 'Resolving',
      HostState.live => session.stats.lost > 0 ? 'Losing packets' : 'Healthy',
    };
    return Semantics(
      label: label,
      child: KeyedSubtree(
        // The shape box only reads `spin` on mount.
        key: ValueKey(state == HostState.live),
        child: PulseShapeBox(
          shape: PulseShape.cookie9,
          color: color,
          size: size,
          spin: state == HostState.live ? PulseMotion.smallSpin : null,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Rows, pills
// ---------------------------------------------------------------------------

/// Trailing live latency: "4.8 ms", "—" when the last probe got no reply.
class HostLatency extends StatelessWidget {
  const HostLatency({super.key, required this.session, this.color});
  final PingSession session;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final v = heroValue(session);
    final down = hostState(session) == HostState.down || hostState(session) == HostState.failed;
    return PulseNumber(v.value, unit: v.unit, live: true, unitScale: .6, color: down ? context.colors.error : color);
  }
}

/// A segmented-list row for one host. Tap opens Ping detail.
class HostListItem extends ConsumerWidget {
  const HostListItem({
    super.key,
    required this.session,
    this.gateway,
    this.selected = false,
    this.color,
    this.minHeight = 58,
    this.onTap,
  });

  final PingSession session;
  final String? gateway;
  final bool selected;
  final Color? color;
  final double minHeight;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sub = hostSubtitle(context, session);
    return Semantics(
      button: true,
      selected: selected,
      label: '${session.title}, ${heroValue(session).value} ${heroValue(session).unit ?? ''}, ${sub.text}',
      excludeSemantics: true,
      child: PulseListItem(
        title: session.title,
        subtitle: sub.text,
        subtitleColor: sub.color,
        selected: selected,
        color: color,
        minHeight: minHeight,
        leading: HostBadge(host: session.host, name: session.name, gateway: gateway),
        trailing: HostLatency(session: session),
        onTap: onTap ?? () => openPingDetail(context, ref, session),
      ),
    );
  }
}

/// Loss pill for host cards: lime "0% loss" with a check, pink "2.3% loss",
/// error "Down", outline "Paused".
class HostLossPill extends StatelessWidget {
  const HostLossPill({super.key, required this.session, this.height = 32});
  final PingSession session;
  final double height;

  @override
  Widget build(BuildContext context) {
    final st = session.stats;
    return switch (hostState(session)) {
      HostState.down || HostState.failed => PulsePill('Down', tone: PulsePillTone.error, height: height),
      HostState.paused => PulsePill('Paused', tone: PulsePillTone.outline, icon: PulseIcons.pause, height: height),
      HostState.done => PulsePill('Done', tone: PulsePillTone.outline, icon: PulseIcons.check, height: height),
      HostState.resolving => PulsePill('Resolving', tone: PulsePillTone.neutral, height: height),
      HostState.live when st.lost > 0 => PulsePill(
        '${fmtPct(st.lossPct)} loss',
        tone: PulsePillTone.pink,
        height: height,
      ),
      HostState.live => PulsePill('0% loss', tone: PulsePillTone.lime, icon: PulseIcons.check, height: height),
    };
  }
}

/// Verdict pill for Ping detail: No loss / Unstable / Degraded / No reply.
class HostVerdictPill extends StatelessWidget {
  const HostVerdictPill({super.key, required this.session, this.height = 32});
  final PingSession session;
  final double height;

  @override
  Widget build(BuildContext context) {
    final st = session.stats;
    final state = hostState(session);
    if (state == HostState.failed) return PulsePill('Lookup failed', tone: PulsePillTone.error, height: height);
    if (state == HostState.down) return PulsePill('No reply', tone: PulsePillTone.error, height: height);
    if (state == HostState.resolving) return PulsePill('Resolving', tone: PulsePillTone.neutral, height: height);
    if (st.sent == 0) return PulsePill('Waiting', tone: PulsePillTone.neutral, height: height);
    if (st.lost == 0) return PulsePill('No loss', tone: PulsePillTone.lime, icon: PulseIcons.check, height: height);
    if (st.lossPct <= 5) return PulsePill('Unstable', tone: PulsePillTone.lavender, height: height);
    return PulsePill('Degraded', tone: PulsePillTone.pink, height: height);
  }
}

/// One sentence explaining the verdict.
String verdictText(PingSession s) {
  final st = s.stats;
  return switch (hostState(s)) {
    HostState.failed => s.error ?? 'The host name could not be resolved.',
    HostState.down => '${noReplyText(s)}. The host may be offline or blocking ping.',
    HostState.resolving => 'Looking up ${s.host}…',
    _ when st.sent == 0 => 'Waiting for the first reply…',
    _ when st.lost == 0 => 'Every packet came back.',
    _ when st.lossPct <= 5 => '${st.lost} of ${st.sent} packets lost, isolated drops.',
    _ => '${st.lost} of ${st.sent} packets lost, likely a congested or failing link.',
  };
}

// ---------------------------------------------------------------------------
// Tablet host card
// ---------------------------------------------------------------------------

/// Tablet Ping home card: badge, name/host, status cookie, 68/900 latency,
/// loss pill, 24-bar sparkline and "Avg · Max · Jitter · N sent".
class HostCard extends ConsumerWidget {
  const HostCard({super.key, required this.session, this.gateway, this.hero = false});
  final PingSession session;
  final String? gateway;
  final bool hero;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final s = session;
    final st = s.stats;
    final fg = hero ? c.onSecondaryContainer : c.onSurface;
    final sub = fg.withValues(alpha: .8);
    final v = heroValue(s);
    final state = hostState(s);
    final down = state == HostState.down || state == HostState.failed;
    final values = chartValues(s, 24);
    final present = values.whereType<double>();
    final top = present.isEmpty ? 1.0 : present.reduce((a, b) => a > b ? a : b) * 1.25;
    TextSpan stat(String k, String val) => TextSpan(
      children: [
        TextSpan(text: '$k '),
        TextSpan(
          text: val,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ],
    );
    return Semantics(
      button: true,
      label: '${s.title}, ${v.value} ${v.unit ?? ''}, ${fmtPct(st.lossPct)} loss, ${hostSubtitle(context, s).text}',
      excludeSemantics: true,
      child: PulseCard(
        color: hero ? c.secondaryContainer : c.surfaceContainer,
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
        onTap: () => openPingDetail(context, ref, s),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                HostBadge(host: s.host, name: s.name, gateway: gateway),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: pulseText(19, 700, height: 1.2).copyWith(color: fg),
                      ),
                      Text(
                        down || state == HostState.paused
                            ? hostSubtitle(context, s).text
                            : (s.name != null ? s.host : (s.describe ?? s.host)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.type.bodySmall!.copyWith(color: down ? c.error : sub),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                HostStatusCookie(session: s),
              ],
            ),
            const Spacer(flex: 3),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.bottomLeft,
                    child: PulseNumber(
                      v.value,
                      unit: v.unit,
                      live: true,
                      unitScale: .25,
                      unitGap: 4,
                      style: pulseText(68, 900, wdth: 120, height: .9, tracking: -.04),
                      color: down ? c.error : (state == HostState.paused ? c.onSurfaceVariant : fg),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                HostLossPill(session: s),
              ],
            ),
            const Spacer(flex: 2),
            PulseBars(values: values, height: 52, barWidth: 9, gap: 5, max: top, fill: true),
            const Spacer(flex: 2),
            DefaultTextStyle(
              style: context.type.bodySmall!.copyWith(color: fg.withValues(alpha: .9)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              child: Row(
                children: [
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          stat('Avg', fmtMs(st.avg)),
                          const TextSpan(text: '    '),
                          stat('Max', fmtMs(st.max)),
                          const TextSpan(text: '    '),
                          stat('Jitter', fmtMs(st.jitter)),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('${fmtCount(st.sent)} sent'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Latency legend: <10 ms · 10–40 · >40.
class LatencyLegend extends StatelessWidget {
  const LatencyLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.pulse;
    Widget item(Color color, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(label, style: context.type.labelMedium!.copyWith(color: context.colors.onSurfaceVariant)),
      ],
    );
    return ExcludeSemantics(
      child: Wrap(
        spacing: 14,
        runSpacing: 4,
        children: [item(t.latFast, '<10 ms'), item(t.latMedium, '10–40'), item(t.latSlow, '>40')],
      ),
    );
  }
}

/// Reply log rows (newest first): seq, time, RTT, TTL, state.
class ReplyLogList extends StatelessWidget {
  const ReplyLogList({super.key, required this.session, this.limit});
  final PingSession session;
  final int? limit;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final all = session.replies.reversed.toList();
    final replies = limit == null ? all : all.take(limit!).toList();
    if (replies.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Text(
          session.resolving ? 'Resolving ${session.host}…' : 'Waiting for the first reply…',
          style: context.type.bodyMedium!.copyWith(color: c.onSurfaceVariant),
        ),
      );
    }
    return PulseSegmentedList(animate: false, children: [for (final r in replies) _ReplyRow(reply: r)]);
  }
}

class _ReplyRow extends StatelessWidget {
  const _ReplyRow({required this.reply});
  final PingReply reply;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final r = reply;
    final state = switch (r.state) {
      ReplyState.ok => 'Reply',
      ReplyState.slow => 'Slow reply',
      ReplyState.timeout => 'No reply',
      ReplyState.unreachable => 'Unreachable',
    };
    final ok = r.received && r.rttMs != null;
    return PulseListItem(
      minHeight: 48,
      title: '#${r.seq} · $state${r.v6 ? ' · IPv6' : ''}',
      titleStyle: context.type.titleSmall,
      subtitle: [fmtTimestamp(r.at), if (r.ttl != null) 'TTL ${r.ttl}', ?r.from].join(' · '),
      leading: Container(
        width: 10,
        height: 10,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: ok ? context.pulse.latencyColor(r.rttMs) : Colors.transparent,
          shape: BoxShape.circle,
          border: ok ? null : Border.all(color: r.state == ReplyState.unreachable ? c.error : c.outline, width: 1.5),
        ),
      ),
      trailing: ok
          ? PulseNumber(fmtMs(r.rttMs), unit: 'ms', unitScale: .6, style: pulseNumber(16))
          : Text('—', style: pulseNumber(16).copyWith(color: c.onSurfaceVariant)),
    );
  }
}
