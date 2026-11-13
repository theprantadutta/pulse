import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/format.dart';
import '../../../core/widgets/pulse/pulse.dart';
import '../../../providers/lan_provider.dart';
import '../../../providers/ping_provider.dart';
import '../../../services/net/lan/lan_scanner.dart';
import '../../../services/net/lan/name_probe.dart';
import '../../../services/net/port_scanner.dart';
import '../../navigation/destinations.dart';
import 'shape_wobble.dart';

/// 10 LAN scan: every device on the local subnet. Phone: summary card, filter
/// chips, the selected device expanded in secondaryContainer and the others in
/// a segmented list. Tablet: summary across the top, chips + device list on the
/// left and a large detail panel on the right.
class LanScreen extends ConsumerStatefulWidget {
  const LanScreen({super.key});

  @override
  ConsumerState<LanScreen> createState() => _LanScreenState();
}

enum _Filter { all, router, phones, unknown, fresh }

class _LanScreenState extends ConsumerState<LanScreen> {
  _Filter _filter = _Filter.all;
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final s = ref.read(lanScanProvider);
      if (s.phase == 'idle') {
        ref.read(lanScanProvider.notifier).scan();
      } else {
        _autoSelect(s);
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Once a scan finishes with nothing selected, open the router (or the first
  /// device) so the detail card is never empty.
  void _autoSelect(LanScanState s) {
    if (s.phase != 'done' || s.selectedIp != null || s.devices.isEmpty) return;
    final pick = s.devices.where((d) => d.host.isGateway).firstOrNull ?? s.devices.first;
    ref.read(lanScanProvider.notifier).select(pick.host.ip);
  }

  void _select(String ip) {
    ref.read(lanScanProvider.notifier).select(ip);
    if (context.isCompact && _scroll.hasClients) {
      _scroll.animateTo(0, duration: PulseMotion.enter, curve: PulseMotion.emphasizedDecelerate);
    }
  }

  bool _matches(LanDevice d) => switch (_filter) {
    _Filter.all => true,
    _Filter.router => d.host.isGateway || d.type == DeviceType.router,
    _Filter.phones => d.type == DeviceType.phone || d.type == DeviceType.tablet,
    _Filter.unknown => d.type == DeviceType.unknown,
    _Filter.fresh => d.isNew,
  };

  @override
  Widget build(BuildContext context) {
    ref.listen(lanScanProvider, (_, next) => _autoSelect(next));
    final s = ref.watch(lanScanProvider);
    final notifier = ref.read(lanScanProvider.notifier);
    final compact = context.isCompact;
    final scan = s.running ? null : notifier.scan;
    final subtitle = s.cidr == null
        ? (s.running ? 'Finding your subnet…' : 'Local subnet')
        : '${s.cidr} · ${s.total} hosts${compact ? '' : ' · ${_method()}'}';

    return PulsePage(
      title: 'LAN scan',
      subtitle: subtitle,
      backTo: Routes.tools,
      actions: [
        if (compact)
          PulseIconButton(
            icon: PulseIcons.refresh,
            tooltip: s.running ? 'Scanning…' : 'Scan again',
            style: PulseIconButtonStyle.pink,
            visualSize: 48,
            onPressed: scan,
          )
        else
          PulseButton(
            label: s.running ? 'Scanning…' : 'Scan again',
            icon: PulseIcons.refresh,
            size: PulseButtonSize.large,
            onPressed: scan,
          ),
      ],
      body: LayoutBuilder(builder: (context, box) => !compact && box.maxWidth >= 720 ? _wide(s, box) : _narrow(s)),
    );
  }

  List<Widget> _chips(LanScanState s) {
    Widget chip(_Filter f, String label) =>
        PulseChip(label: label, small: true, selected: _filter == f, onTap: () => setState(() => _filter = f));
    final fresh = s.devices.where((d) => d.isNew).length;
    return [
      chip(_Filter.all, 'All ${s.devices.length}'),
      chip(_Filter.router, 'Router'),
      chip(_Filter.phones, 'Phones'),
      chip(_Filter.unknown, 'Unknown'),
      if (fresh > 0) chip(_Filter.fresh, 'New $fresh'),
    ];
  }

  Widget _methodChip() => Tooltip(
    message: _mobileOs
        ? '$_osName hides the ARP table, so Pulse finds devices by ping (ICMP) and common TCP ports.'
        : 'Pulse pings every address (ICMP) and reads the ARP table for MAC addresses.',
    child: PulseChip(label: _method(), small: true, icon: PulseIcons.info),
  );

  Widget _narrow(LanScanState s) {
    final pad = context.pagePadding;
    final selected = s.selected;
    final showCard = selected != null && _matches(selected);
    final others = [
      for (final d in s.devices)
        if (_matches(d) && d.host.ip != (showCard ? selected.host.ip : null)) d,
    ];
    Widget padded(Widget w) => Padding(
      padding: EdgeInsets.symmetric(horizontal: pad),
      child: w,
    );
    final children = <Widget>[
      padded(_Summary(state: s)),
      if (s.error != null) padded(_ErrorBanner(state: s)),
      if (s.devices.isNotEmpty)
        PulseChipRow(
          padding: EdgeInsets.symmetric(horizontal: pad),
          children: [..._chips(s), _methodChip()],
        ),
      if (showCard) padded(_DeviceCard(device: selected, state: s)),
      if (others.isNotEmpty)
        padded(_DeviceList(devices: others, selectedIp: null, onSelect: _select))
      else if (s.devices.isNotEmpty && !showCard)
        padded(_NoMatch(onReset: () => setState(() => _filter = _Filter.all))),
      if (s.devices.isEmpty && s.phase == 'done' && s.error == null) padded(_NoDevices(state: s)),
    ];
    return ListView(
      controller: _scroll,
      padding: const EdgeInsets.only(top: 4, bottom: 24),
      children: [
        for (var i = 0; i < children.length; i++)
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : PulseLayout.section),
            child: PulseEntrance(index: math.min(i, 4), child: children[i]),
          ),
      ],
    );
  }

  Widget _wide(LanScanState s, BoxConstraints box) {
    const pad = PulseLayout.tabletPadding;
    final listWidth = math.min(330.0, (box.maxWidth - pad * 2) * .42);
    final visible = [
      for (final d in s.devices)
        if (_matches(d)) d,
    ];
    final selected = s.selected;
    return Padding(
      padding: const EdgeInsets.fromLTRB(pad, 4, pad, pad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PulseEntrance(child: _Summary(state: s, wide: true)),
          if (s.error != null) ...[const SizedBox(height: PulseLayout.section), _ErrorBanner(state: s)],
          const SizedBox(height: 14),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: listWidth,
                  child: ListView(
                    children: [
                      if (s.devices.isNotEmpty) ...[
                        Wrap(spacing: 8, children: [for (final c in _chips(s)) IntrinsicWidth(child: c)]),
                        const SizedBox(height: 10),
                      ],
                      if (visible.isNotEmpty)
                        _DeviceList(devices: visible, selectedIp: selected?.host.ip, onSelect: _select, roomy: true)
                      else if (s.devices.isNotEmpty)
                        _NoMatch(onReset: () => setState(() => _filter = _Filter.all))
                      else if (s.phase == 'done' && s.error == null)
                        _NoDevices(state: s),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: PulseEntrance(
                    index: 1,
                    child: selected == null ? _PanelPlaceholder(state: s) : _DetailPanel(device: selected, state: s),
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

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

bool get _mobileOs => defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS;

String get _osName => defaultTargetPlatform == TargetPlatform.iOS ? 'iOS' : 'Android';

/// Discovery method: phones can't read the ARP table.
/// Shortest side ≥ 600 dp, the same split the shell and main.dart use.
bool get _isTablet {
  final views = WidgetsBinding.instance.platformDispatcher.views;
  if (views.isEmpty) return false;
  final v = views.first;
  return v.physicalSize.shortestSide / v.devicePixelRatio >= 600;
}

String _method() => _mobileOs ? 'ICMP + TCP' : 'ARP + ICMP';

String _macPrivacy() =>
    '$_osName does not let apps read the ARP table, so MAC addresses of other devices stay hidden. '
    'Wake-on-LAN needs the MAC, so it is only available from Pulse on Windows, macOS or Linux.';

String _deviceName(LanDevice d) =>
    d.host.hostname ??
    (d.host.isGateway
        ? 'Router'
        : d.host.isSelf
        ? 'This device'
        : 'Unknown device');

bool _unknown(LanDevice d) => d.host.hostname == null && d.host.vendor == null && !d.host.isGateway && !d.host.isSelf;

PulseIcons _iconFor(LanDevice d) {
  if (d.host.isGateway) return PulseIcons.router;
  if (d.host.isSelf) return _mobileOs ? PulseIcons.phone : PulseIcons.laptop;
  return switch (d.type) {
    DeviceType.router => PulseIcons.router,
    DeviceType.pc => PulseIcons.laptop,
    DeviceType.phone || DeviceType.tablet => PulseIcons.phone,
    DeviceType.storage => PulseIcons.data,
    DeviceType.iot => PulseIcons.wifi,
    DeviceType.unknown => PulseIcons.help,
    _ => PulseIcons.lan,
  };
}

/// "gateway", vendor, or the device type, for the subtitle.
String? _role(LanDevice d) {
  if (d.host.isGateway) return 'gateway';
  if (d.host.isSelf) return _mobileOs ? (_isTablet ? 'tablet' : 'phone') : 'this computer';
  if (d.type != DeviceType.unknown) return d.type.label.toLowerCase();
  return null;
}

String _firstSeen(LanDevice d) => d.firstSeen == null ? 'This scan' : DateFormat('MMM d, HH:mm').format(d.firstSeen!);

String _mac(LanDevice d) => d.host.mac ?? (_mobileOs ? 'Hidden by $_osName' : '—');

String _secs(Duration? d) => d == null ? '' : '${(d.inMilliseconds / 1000).toStringAsFixed(1)} s';

String _status(LanScanState s, {bool wide = false}) {
  final hosts = wide ? ' hosts' : '';
  return switch (s.phase) {
    'probing' =>
      'Scanning · ${s.probed} of ${s.total}$hosts'
          '${s.current == null ? '' : ' · .${s.current!.split('.').last}'}',
    'arp' => 'Reading the ARP table · ${s.total} of ${s.total}$hosts',
    'names' => 'Resolving names and vendors…',
    'done' when s.error != null => 'Scan stopped',
    'done' => 'Scan complete · ${s.total} of ${s.total}$hosts · ${_secs(s.elapsed)}',
    _ => 'Ready to scan',
  };
}

double _progress(LanScanState s) => switch (s.phase) {
  'probing' => s.total == 0 ? 0 : s.probed / s.total,
  'arp' || 'names' => .97,
  'done' => s.error == null ? 1 : 0,
  _ => 0,
};

void _snack(BuildContext context, String text) => ScaffoldMessenger.maybeOf(context)
  ?..hideCurrentSnackBar()
  ..showSnackBar(SnackBar(content: Text(text)));

Future<void> _ping(BuildContext context, WidgetRef ref, LanDevice d) async {
  final id = await ref
      .read(pingBoardProvider.notifier)
      .start(d.host.ip, name: d.host.hostname ?? (d.host.isGateway ? 'Router' : null));
  if (!context.mounted) return;
  if (id == null) {
    _snack(context, 'Too many live pings. Stop one on the Ping screen first.');
    context.go(Routes.ping);
  } else {
    context.go('${Routes.pingDetail}?id=${Uri.encodeQueryComponent(id)}');
  }
}

Future<void> _wake(BuildContext context, LanDevice d, String? broadcast) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  try {
    await WakeOnLan.wake(d.host.mac!, broadcasts: [?broadcast, '255.255.255.255']);
    messenger?.showSnackBar(SnackBar(content: Text('Magic packet sent to ${d.host.mac}')));
  } on Object catch (e) {
    messenger?.showSnackBar(SnackBar(content: Text('Wake failed: $e')));
  }
}

String _asText(LanDevice d, List<PortResult>? ports) => [
  '${_deviceName(d)} · ${d.host.ip}',
  if (d.host.hostname != null) 'Hostname: ${d.host.hostname}',
  if (d.host.vendor != null) 'Vendor: ${d.host.vendor}',
  if (d.host.mac != null) 'MAC: ${d.host.mac}',
  if (d.host.rttMs != null) 'RTT: ${fmtMs(d.host.rttMs)} ms',
  if (ports != null && ports.isNotEmpty) 'Open ports: ${ports.map((p) => p.port).join(', ')}',
  'First seen: ${_firstSeen(d)}',
].join('\n');

// ---------------------------------------------------------------------------
// Summary
// ---------------------------------------------------------------------------

class _Summary extends StatelessWidget {
  const _Summary({required this.state, this.wide = false});
  final LanScanState state;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final s = state;
    final c = context.colors;
    final size = wide ? 76.0 : 84.0;
    final bar = PulseWavyBar(value: _progress(s), semanticLabel: 'Scan progress');
    final count = Semantics(
      label: '${s.devices.length} devices found',
      liveRegion: s.running,
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            ShapeWobble(
              child: PulseShapeBox(shape: PulseShape.clover4, color: PulseTone.lime.fill(context), size: size),
            ),
            PulseLiveValue(
              '${s.devices.length}',
              style: pulseText(wide ? 38 : 40, 900, wdth: 120, height: 1).copyWith(color: PulseTone.lime.on(context)),
            ),
          ],
        ),
      ),
    );
    return PulseCard(
      padding: wide ? const EdgeInsets.fromLTRB(20, 16, 24, 16) : const EdgeInsets.all(16),
      child: Row(
        children: [
          PulsePop(child: count),
          SizedBox(width: wide ? 18 : 16),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Devices found', style: context.type.titleLarge),
                const SizedBox(height: 4),
                Text(
                  _status(s, wide: wide),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.type.bodyMedium!.copyWith(color: c.onSurfaceVariant),
                ),
                if (!wide) ...[
                  const SizedBox(height: 8),
                  ConstrainedBox(constraints: const BoxConstraints(maxWidth: 220), child: bar),
                ],
              ],
            ),
          ),
          if (wide) ...[const SizedBox(width: 16), SizedBox(width: 300, child: bar)],
        ],
      ),
    );
  }
}

class _ErrorBanner extends ConsumerWidget {
  const _ErrorBanner({required this.state});
  final LanScanState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) => PulseErrorBanner(
    title: "Couldn't scan this network",
    message: state.error,
    onRetry: state.running ? null : ref.read(lanScanProvider.notifier).scan,
    retryLabel: 'Scan again',
  );
}

class _NoDevices extends ConsumerWidget {
  const _NoDevices({required this.state});
  final LanScanState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) => PulseEmptyState(
    title: 'No devices found',
    message: 'Nothing answered on ${state.cidr ?? 'this network'}.',
    shape: PulseShape.clover4,
    icon: PulseIcons.lan,
    action: IntrinsicWidth(
      child: PulseButton(
        label: 'Scan again',
        icon: PulseIcons.refresh,
        style: PulseButtonStyle.tonal,
        onPressed: ref.read(lanScanProvider.notifier).scan,
      ),
    ),
  );
}

class _NoMatch extends StatelessWidget {
  const _NoMatch({required this.onReset});
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) => PulseCard(
    child: Row(
      children: [
        Expanded(
          child: Text(
            'No devices match this filter.',
            style: context.type.bodyMedium!.copyWith(color: context.colors.onSurfaceVariant),
          ),
        ),
        PulseButton(label: 'Show all', style: PulseButtonStyle.text, size: PulseButtonSize.small, onPressed: onReset),
      ],
    ),
  );
}

// ---------------------------------------------------------------------------
// Device list
// ---------------------------------------------------------------------------

/// Segmented device list. Rows are keyed by IP so devices found mid-scan pop in
/// without re-animating the rest.
class _DeviceList extends StatelessWidget {
  const _DeviceList({required this.devices, required this.selectedIp, required this.onSelect, this.roomy = false});
  final List<LanDevice> devices;
  final String? selectedIp;
  final ValueChanged<String> onSelect;
  final bool roomy;

  @override
  Widget build(BuildContext context) {
    final n = devices.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < n; i++)
          Padding(
            key: ValueKey(devices[i].host.ip),
            padding: EdgeInsets.only(top: i == 0 ? 0 : PulseLayout.seam),
            child: PulseEntrance(
              index: math.min(i, 8),
              child: _DeviceRow(
                device: devices[i],
                radius: segmentedRadius(i, n),
                selected: devices[i].host.ip == selectedIp,
                roomy: roomy,
                onTap: () => onSelect(devices[i].host.ip),
              ),
            ),
          ),
      ],
    );
  }
}

class _DeviceRow extends StatelessWidget {
  const _DeviceRow({
    required this.device,
    required this.radius,
    required this.selected,
    required this.roomy,
    required this.onTap,
  });
  final LanDevice device;
  final BorderRadius radius;
  final bool selected;
  final bool roomy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final d = device;
    final fg = selected ? c.onSecondaryContainer : c.onSurface;
    final sub = selected ? c.onSecondaryContainer.withValues(alpha: .85) : c.onSurfaceVariant;
    final subtitle = [d.host.ip, ?_role(d), if (d.isNew) 'new'].join(' · ');
    return Semantics(
      button: true,
      selected: selected,
      label:
          '${_deviceName(d)}, $subtitle, '
          '${d.host.rttMs == null ? 'answered ARP only' : '${fmtMs(d.host.rttMs)} milliseconds'}',
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: PulseMotion.shapeMorph,
        curve: PulseMotion.spring,
        decoration: BoxDecoration(
          color: selected ? c.secondaryContainer : c.surfaceContainer,
          borderRadius: selected ? BorderRadius.circular(28) : radius,
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: roomy ? 68 : 60),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 18, 8),
                child: Row(
                  children: [
                    _DeviceBadge(device: d),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _deviceName(d),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.type.titleMedium!.copyWith(fontSize: 17, color: fg),
                          ),
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.type.bodySmall!.copyWith(fontSize: 14, color: sub),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    _Rtt(ms: d.host.rttMs, color: fg),
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

class _Rtt extends StatelessWidget {
  const _Rtt({required this.ms, required this.color, this.size = 22});
  final double? ms;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (ms == null) {
      return Tooltip(
        message: 'Answered ARP only (no ping reply)',
        child: Text('ARP', style: context.type.labelLarge!.copyWith(color: color.withValues(alpha: .8))),
      );
    }
    return PulseNumber(fmtMs(ms), unit: 'ms', unitScale: .6, style: pulseNumber(size), color: color);
  }
}

/// Router: lavender circle. This device: tertiaryContainer rounded square.
/// Unknown: dashed outline circle with "?". Others: a quiet circle.
class _DeviceBadge extends StatelessWidget {
  const _DeviceBadge({required this.device});
  final LanDevice device;
  static const size = 40.0;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final d = device;
    final icon = _iconFor(d);
    if (d.host.isGateway || d.type == DeviceType.router) {
      return PulseShapeBadge(shape: PulseShape.circle, tone: PulseTone.lavender, icon: icon, size: size);
    }
    if (d.host.isSelf) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: c.tertiaryContainer, borderRadius: BorderRadius.circular(size * .3)),
        child: Center(
          child: PulseIcon(icon, size: size * .5, color: c.onTertiaryContainer),
        ),
      );
    }
    if (_unknown(d)) {
      return CustomPaint(
        painter: _DashedCircle(c.outline),
        child: SizedBox.square(
          dimension: size,
          child: Center(
            child: PulseIcon(PulseIcons.help, size: size * .5, color: c.onSurfaceVariant),
          ),
        ),
      );
    }
    return PulseContainerBadge(
      shape: PulseShape.circle,
      icon: icon,
      color: c.surfaceContainerHighest,
      onColor: c.onSurfaceVariant,
      size: size,
    );
  }
}

class _DashedCircle extends CustomPainter {
  _DashedCircle(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final r = size.shortestSide / 2 - 1;
    final center = size.center(Offset.zero);
    const dashes = 12;
    const sweep = 2 * math.pi / dashes;
    for (var i = 0; i < dashes; i++) {
      canvas.drawArc(Rect.fromCircle(center: center, radius: r), i * sweep, sweep * .55, false, p);
    }
  }

  @override
  bool shouldRepaint(_DashedCircle old) => old.color != color;
}

// ---------------------------------------------------------------------------
// Device details (phone card, tablet panel)
// ---------------------------------------------------------------------------

/// Small badge after the device name ("Gateway", "This device", "New").
class _NameBadge extends StatelessWidget {
  const _NameBadge(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(color: c.onSecondaryContainer, borderRadius: BorderRadius.circular(11)),
      alignment: Alignment.center,
      child: Text(label, style: pulseText(11, 700, wdth: 105).copyWith(color: c.secondaryContainer)),
    );
  }
}

String? _badgeFor(LanDevice d) => d.host.isGateway
    ? 'Gateway'
    : d.host.isSelf
    ? 'This device'
    : d.isNew
    ? 'New'
    : null;

/// Hostname · Vendor · MAC · First seen, two per row.
class _InfoGrid extends StatelessWidget {
  const _InfoGrid({required this.device, this.large = false});
  final LanDevice device;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final d = device;
    final hidden = d.host.mac == null && _mobileOs;
    Widget cell(String label, String value, {bool privacy = false}) =>
        _InfoCell(label: label, value: value, large: large, privacy: privacy);
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: cell('Hostname', d.host.hostname ?? '—')),
            SizedBox(width: large ? 24 : 16),
            Expanded(child: cell('Vendor', d.host.vendor ?? '—')),
          ],
        ),
        SizedBox(height: large ? 16 : 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: cell('MAC', _mac(d), privacy: hidden)),
            SizedBox(width: large ? 24 : 16),
            Expanded(child: cell('First seen', _firstSeen(d))),
          ],
        ),
      ],
    );
  }
}

class _InfoCell extends StatelessWidget {
  const _InfoCell({required this.label, required this.value, required this.large, this.privacy = false});
  final String label, value;
  final bool large;

  /// OS-hidden value: the whole cell opens the explanation (info icon inline).
  final bool privacy;

  @override
  Widget build(BuildContext context) {
    final on = context.colors.onSecondaryContainer;
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: pulseText(large ? 13 : 12, 400).copyWith(color: on.withValues(alpha: .8))),
        Row(
          children: [
            Flexible(
              child: Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: pulseText(large ? 17 : 14, 700, height: 1.3).copyWith(color: on),
              ),
            ),
            if (privacy) ...[const SizedBox(width: 6), PulseIcon(PulseIcons.info, size: 16, color: on)],
          ],
        ),
      ],
    );
    if (!privacy) return body;
    return Semantics(
      button: true,
      label: '$label $value. Why is this hidden?',
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Hidden by the system'),
            content: Text(_macPrivacy()),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
          ),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Align(alignment: Alignment.centerLeft, widthFactor: 1, child: body),
        ),
      ),
    );
  }
}

/// "Open ports" with pills (port number, plus the service name when [named]).
class _OpenPorts extends ConsumerWidget {
  const _OpenPorts({required this.device, required this.state, this.large = false});
  final LanDevice device;
  final LanScanState state;
  final bool large;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final on = c.onSecondaryContainer;
    final ip = device.host.ip;
    final ports = state.ports[ip];
    final scanning = state.scanningPorts.contains(ip);
    final labelStyle = pulseText(large ? 13 : 12, 400).copyWith(color: on.withValues(alpha: .8));
    final h = large ? 34.0 : 28.0;
    Widget pill(PortResult p) => Tooltip(
      message: p.banner ?? (p.service == 'unknown' ? 'Port ${p.port}' : p.service),
      child: Container(
        height: h,
        padding: EdgeInsets.symmetric(horizontal: large ? 14 : 12),
        decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(h / 2)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${p.port}', style: pulseNumber(large ? 15 : 14).copyWith(color: c.onSurface)),
            if (large && p.service != 'unknown') ...[
              const SizedBox(width: 6),
              Text(
                p.service.toUpperCase(),
                style: pulseText(15, 500).copyWith(color: c.onSurface.withValues(alpha: .8)),
              ),
            ],
          ],
        ),
      ),
    );
    final Widget content;
    if (scanning) {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PulseLiveDot(color: on, size: 7),
          const SizedBox(width: 8),
          Text('Checking common ports…', style: pulseText(large ? 15 : 13, 600).copyWith(color: on)),
        ],
      );
    } else if (ports == null && state.running) {
      content = Text('Checked when the scan ends', style: pulseText(large ? 15 : 13, 600).copyWith(color: on));
    } else if (ports == null) {
      content = Align(
        alignment: Alignment.centerLeft,
        child: IntrinsicWidth(
          child: PulseButton(
            label: 'Check common ports',
            style: PulseButtonStyle.text,
            size: PulseButtonSize.small,
            onPressed: () => ref.read(lanScanProvider.notifier).scanPorts(ip),
          ),
        ),
      );
    } else if (ports.isEmpty) {
      content = Text('None of the common ports', style: pulseText(large ? 15 : 13, 600).copyWith(color: on));
    } else {
      content = Wrap(spacing: 6, runSpacing: 6, children: [for (final p in ports) pill(p)]);
    }
    if (large) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Open ports', style: labelStyle),
          const SizedBox(height: 8),
          content,
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text('Open ports', style: labelStyle),
        const SizedBox(width: 8),
        Expanded(child: content),
      ],
    );
  }
}

class _Actions extends ConsumerWidget {
  const _Actions({required this.device, required this.state, this.large = false, this.copy = false});
  final LanDevice device;
  final LanScanState state;
  final bool large;

  /// Phone card: the copy button sits at the end of the actions.
  final bool copy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = device;
    final size = large ? PulseButtonSize.large : PulseButtonSize.small;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      // IntrinsicWidth: PulseButton stretches to the width a Wrap offers.
      children: [
        for (final b in <Widget>[
          PulseButton(label: 'Ping', icon: PulseIcons.pulse, size: size, onPressed: () => _ping(context, ref, d)),
          PulseButton(
            label: large ? 'Scan ports' : 'Ports',
            icon: PulseIcons.port,
            style: PulseButtonStyle.neutral,
            size: size,
            onPressed: () => context.go('${Routes.ports}?target=${d.host.ip}'),
          ),
          // Phones can't read MACs (Android hides them), so a dead Wake button
          // would only push the copy button onto its own line.
          if (d.host.mac != null || !copy)
            PulseButton(
              label: large ? 'Wake on LAN' : 'Wake',
              icon: PulseIcons.power,
              style: PulseButtonStyle.text,
              size: size,
              tooltip: d.host.mac == null ? 'Needs the device MAC address' : 'Send a Wake-on-LAN magic packet',
              onPressed: d.host.mac == null ? null : () => _wake(context, d, state.broadcast),
            ),
        ])
          IntrinsicWidth(child: b),
        if (copy) _CopyDevice(device: d, state: state),
      ],
    );
  }
}

class _CopyDevice extends StatelessWidget {
  const _CopyDevice({required this.device, required this.state});
  final LanDevice device;
  final LanScanState state;

  @override
  Widget build(BuildContext context) => PulseIconButton(
    icon: PulseIcons.copy,
    tooltip: 'Copy device details',
    color: context.colors.onSecondaryContainer,
    iconSize: 20,
    onPressed: () {
      Clipboard.setData(ClipboardData(text: _asText(device, state.ports[device.host.ip])));
      _snack(context, 'Copied ${device.host.ip}');
    },
  );
}

/// Phone: the selected device expanded in secondaryContainer.
class _DeviceCard extends StatelessWidget {
  const _DeviceCard({required this.device, required this.state});
  final LanDevice device;
  final LanScanState state;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final on = c.onSecondaryContainer;
    final d = device;
    final badge = _badgeFor(d);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(color: c.secondaryContainer, borderRadius: BorderRadius.circular(28)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              PulseShapeBadge(shape: PulseShape.circle, tone: PulseTone.lavender, icon: _iconFor(d), size: 44),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            _deviceName(d),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: pulseText(17, 700, height: 1.25).copyWith(color: on),
                          ),
                        ),
                        if (badge != null) ...[const SizedBox(width: 8), _NameBadge(badge)],
                      ],
                    ),
                    Text(d.host.ip, style: pulseText(14, 400).copyWith(color: on.withValues(alpha: .85))),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _Rtt(ms: d.host.rttMs, color: on, size: 20),
            ],
          ),
          const SizedBox(height: 14),
          _InfoGrid(device: d),
          const SizedBox(height: 12),
          _OpenPorts(device: d, state: state),
          const SizedBox(height: 14),
          _Actions(device: d, state: state, copy: true),
        ],
      ),
    );
  }
}

/// Tablet: the large detail panel.
class _DetailPanel extends StatelessWidget {
  const _DetailPanel({required this.device, required this.state});
  final LanDevice device;
  final LanScanState state;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final on = c.onSecondaryContainer;
    final d = device;
    final line = [
      _deviceName(d),
      ?_role(d),
      if (d.host.rttMs != null) 'RTT ${fmtMs(d.host.rttMs)} ms' else 'ARP only',
    ].join(' · ');
    return Container(
      padding: const EdgeInsets.fromLTRB(26, 22, 18, 22),
      decoration: BoxDecoration(color: c.secondaryContainer, borderRadius: BorderRadius.circular(32)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(right: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      PulseShapeBadge(
                        shape: PulseShape.cookie9,
                        tone: PulseTone.lavender,
                        icon: _iconFor(d),
                        size: 64,
                        spin: PulseMotion.smallSpin,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                d.host.ip,
                                maxLines: 1,
                                style: pulseText(30, 900, wdth: 115, height: 1.15).copyWith(color: on),
                              ),
                            ),
                            Text(
                              line,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: pulseText(14, 400).copyWith(color: on.withValues(alpha: .85)),
                            ),
                          ],
                        ),
                      ),
                      _CopyDevice(device: d, state: state),
                    ],
                  ),
                  const SizedBox(height: 22),
                  _InfoGrid(device: d, large: true),
                  const SizedBox(height: 20),
                  _OpenPorts(device: d, state: state, large: true),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _Actions(device: d, state: state, large: true),
        ],
      ),
    );
  }
}

class _PanelPlaceholder extends StatelessWidget {
  const _PanelPlaceholder({required this.state});
  final LanScanState state;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(color: context.colors.surfaceContainer, borderRadius: BorderRadius.circular(32)),
    alignment: Alignment.center,
    child: SingleChildScrollView(
      child: PulseEmptyState(
        title: state.running ? 'Looking for devices' : 'Pick a device',
        message: state.running
            ? 'Devices appear on the left as they answer.'
            : 'Select a device to see its vendor, open ports and actions.',
        shape: PulseShape.clover4,
        icon: PulseIcons.lan,
      ),
    ),
  );
}
