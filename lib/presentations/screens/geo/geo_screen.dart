import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/format.dart';
import '../../../core/widgets/pulse/pulse.dart';
import '../../../providers/geo_provider.dart';
import '../../../providers/ping_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../services/net/geo_ip.dart';
import '../../navigation/destinations.dart';
import 'world_map.dart';

/// 11 Geo IP: where a host lives, how far away it is and who hosts it, on an
/// offline vector map with the route from your public-IP location.
class GeoScreen extends ConsumerStatefulWidget {
  const GeoScreen({super.key, this.initialTarget});
  final String? initialTarget;

  @override
  ConsumerState<GeoScreen> createState() => _GeoScreenState();
}

class _GeoScreenState extends ConsumerState<GeoScreen> {
  late final _query = TextEditingController(text: widget.initialTarget ?? ref.read(geoProvider).query);

  @override
  void initState() {
    super.initState();
    _query.addListener(_onText);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !ref.read(settingsProvider).publicIpLookups) return;
      final geo = ref.read(geoProvider.notifier);
      final s = ref.read(geoProvider);
      if (widget.initialTarget != null) {
        geo.locate(widget.initialTarget!);
      } else if (s.target == null && !s.loading && (s.error == null || _lookupsOffError(s.error!))) {
        // Lookups were off last time and are on again: the old error is stale.
        _myIp();
      }
    });
  }

  @override
  void dispose() {
    _query
      ..removeListener(_onText)
      ..dispose();
    super.dispose();
  }

  String _lastText = '';
  void _onText() {
    // Only the "Locate" affordance depends on the text; rebuild when it flips.
    if (_query.text.trim() != _lastText) setState(() => _lastText = _query.text.trim());
  }

  void _locate() {
    if (_query.text.trim().isEmpty) return;
    FocusManager.instance.primaryFocus?.unfocus();
    ref.read(geoProvider.notifier).locate(_query.text);
  }

  Future<void> _myIp() async {
    await ref.read(geoProvider.notifier).locateMe();
    if (mounted && ref.read(geoProvider).query.isNotEmpty) _query.text = ref.read(geoProvider).query;
  }

  Future<void> _ping(GeoState s) async {
    await ref.read(pingBoardProvider.notifier).start(s.query, name: s.target?.city);
    if (mounted) context.go(Routes.ping);
  }

  void _trace(GeoState s) => context.go('${Routes.traceroute}?target=${Uri.encodeComponent(s.query)}');

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(geoProvider);
    final lookupsOn = ref.watch(settingsProvider.select((x) => x.publicIpLookups));
    final v = _GeoView(
      state: s,
      lookupsOn: lookupsOn,
      onLocate: _locate,
      onMyIp: _myIp,
      onPing: () => _ping(s),
      onTrace: () => _trace(s),
    );
    final canAct = lookupsOn && !s.loading;
    if (context.isCompact) {
      return PulsePage(
        title: 'Geo IP',
        backTo: Routes.tools,
        actions: [
          PulseButton(
            label: 'My IP',
            style: PulseButtonStyle.text,
            size: PulseButtonSize.small,
            onPressed: canAct ? _myIp : null,
          ),
        ],
        children: [_field(s, compact: true), ...v.phone(context)],
      );
    }
    // Portrait tablets, and landscape next to the Tools pane, leave the header
    // field too little room (the host was clipped by "→ ip"): give it a row of
    // its own unless the page itself is wide. The title and buttons take ~460 dp.
    return LayoutBuilder(builder: (context, box) => _tabletPage(s, v, canAct, narrow: box.maxWidth < 900));
  }

  Widget _tabletPage(GeoState s, _GeoView v, bool canAct, {required bool narrow}) {
    return PulsePage(
      title: 'Geo IP',
      titleWidget: narrow
          ? null
          : Row(
              children: [
                Text('Geo IP', style: context.type.headlineMedium),
                const SizedBox(width: 16),
                Expanded(child: _field(s, compact: false)),
              ],
            ),
      actions: [
        PulseButton(label: 'My IP', style: PulseButtonStyle.tonal, onPressed: canAct ? _myIp : null),
        PulseButton(
          label: s.loading ? 'Locating…' : 'Locate',
          size: PulseButtonSize.large,
          onPressed: canAct ? _locate : null,
        ),
      ],
      body: narrow
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(PulseLayout.tabletPadding, 0, PulseLayout.tabletPadding, 12),
                  child: _field(s, compact: false),
                ),
                Expanded(child: v.tablet(context)),
              ],
            )
          : v.tablet(context),
    );
  }

  Widget _field(GeoState s, {required bool compact}) {
    final text = _query.text.trim();
    final stale = text.isNotEmpty && text != s.query;
    final ip = s.resolvedIp != null && s.resolvedIp != s.query && !stale ? s.resolvedIp : null;
    return PulseTargetField(
      controller: _query,
      hint: 'Domain or IP',
      onSubmitted: (_) => _locate(),
      trailing: ip == null ? null : (compact ? ip : '→ $ip'),
      // Phones always have a Locate button (pink when the text changed, so a
      // new lookup is pending; quiet when it would just run the same host again).
      trailingWidget: compact && text.isNotEmpty && !s.loading
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (ip != null)
                  Text(ip, style: context.type.bodySmall!.copyWith(color: context.colors.onSurfaceVariant)),
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: PulseIconButton(
                    icon: PulseIcons.pin,
                    tooltip: stale ? 'Locate' : 'Locate again',
                    style: stale ? PulseIconButtonStyle.pink : PulseIconButtonStyle.neutral,
                    visualSize: 40,
                    iconSize: 20,
                    onPressed: _locate,
                  ),
                ),
              ],
            )
          : null,
    );
  }
}

/// Builds the phone and tablet bodies from the provider state.
class _GeoView {
  const _GeoView({
    required this.state,
    required this.lookupsOn,
    required this.onLocate,
    required this.onMyIp,
    required this.onPing,
    required this.onTrace,
  });

  final GeoState state;
  final bool lookupsOn;
  final VoidCallback onLocate, onMyIp, onPing, onTrace;

  GeoInfo? get target => state.target;

  /// The lookup was for this device's own public IP.
  bool get isSelf => target != null && state.me != null && target!.ip == state.me!.ip;

  MapPoint? get youPoint {
    final me = state.me;
    if (me?.lat == null || me?.lon == null) return null;
    final where = _nonBlank([me!.city, me.country, me.countryCode]) ?? me.ip;
    return MapPoint(me.lat!, me.lon!, 'You · $where');
  }

  MapPoint? get targetPoint {
    final g = target;
    if (g?.lat == null || g?.lon == null || isSelf) return null;
    return MapPoint(g!.lat!, g.lon!, _place(g));
  }

  Widget _map(BuildContext context, {required bool interactive}) {
    final map = GeoRouteMap(you: youPoint, target: lookupsOn ? targetPoint : null, interactive: interactive);
    if (interactive) return map;
    // Embedded in a scrolling page, map gestures would fight the scroll, so
    // the small map opens a full-screen one that pans and zooms freely.
    return Stack(
      children: [
        Positioned.fill(child: map),
        Positioned.fill(
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: BorderRadius.circular(28),
              onTap: () => _openFullMap(context),
              child: const SizedBox.expand(),
            ),
          ),
        ),
        Positioned(
          right: 4,
          top: 4,
          child: PulseIconButton(
            icon: PulseIcons.search,
            tooltip: 'Open map',
            style: PulseIconButtonStyle.neutral,
            visualSize: 40,
            iconSize: 20,
            onPressed: () => _openFullMap(context),
          ),
        ),
      ],
    );
  }

  void _openFullMap(BuildContext context) {
    final you = youPoint;
    final there = lookupsOn ? targetPoint : null;
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (context) => Scaffold(
          backgroundColor: context.colors.surface,
          body: SafeArea(
            child: Stack(
              children: [
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: GeoRouteMap(you: you, target: there, interactive: true),
                  ),
                ),
                Positioned(
                  left: 12,
                  top: 12,
                  child: PulseIconButton(
                    icon: PulseIcons.x,
                    tooltip: 'Close map',
                    style: PulseIconButtonStyle.neutral,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---- Phone ---------------------------------------------------------------

  List<Widget> phone(BuildContext context) {
    final g = target;
    return [
      if (!lookupsOn) ...[
        const SizedBox(height: 12),
        const _LookupsOff(),
      ] else ...[
        if (state.error != null) ...[const SizedBox(height: 12), _error()],
        const SizedBox(height: 12),
        SizedBox(height: 250, child: _map(context, interactive: false)),
        if (state.loading) ...[const SizedBox(height: 14), _Locating(query: state.query)],
        if (g != null) ...[
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                Expanded(child: _PlaceTitle(g: g)),
                const SizedBox(width: 8),
                PulseIconButton(
                  icon: PulseIcons.pulse,
                  tooltip: 'Ping this',
                  style: PulseIconButtonStyle.tonal,
                  visualSize: 48,
                  onPressed: onPing,
                ),
                const SizedBox(width: 6),
                PulseIconButton(
                  icon: PulseIcons.route,
                  tooltip: 'Trace route',
                  style: PulseIconButtonStyle.pink,
                  visualSize: 48,
                  onPressed: onTrace,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: _pills(height: 30)),
          const SizedBox(height: 12),
          _DetailList(rows: _rows(g, full: false), rowHeight: 46),
          const SizedBox(height: 10),
          _SourceNote(source: g.source),
        ] else if (!state.loading && state.error == null) ...[
          const SizedBox(height: 8),
          _Idle(onMyIp: onMyIp),
        ],
      ],
    ];
  }

  // ---- Tablet --------------------------------------------------------------

  Widget tablet(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final pad = context.pagePadding;
      if (box.maxWidth < 720) {
        // Portrait tablets / narrow windows: one scrolling column.
        return ListView(
          padding: EdgeInsets.fromLTRB(pad, 0, pad, pad),
          children: [
            for (final (i, w) in [
              SizedBox(height: 340, child: _map(context, interactive: false)),
              ..._side(context, scrolls: false),
            ].indexed)
              PulseEntrance(index: i, child: w),
          ],
        );
      }
      return Padding(
        padding: EdgeInsets.fromLTRB(pad, 0, pad, pad),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(flex: 55, child: PulseEntrance(child: _map(context, interactive: true))),
            const SizedBox(width: 16),
            Expanded(
              flex: 45,
              child: CustomScrollView(
                slivers: [
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final (i, w) in _side(context, scrolls: true).indexed)
                          w is Spacer ? w : PulseEntrance(index: i + 1, child: w),
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
  );

  /// Right-hand column (or the part below the map on narrow tablets).
  List<Widget> _side(BuildContext context, {required bool scrolls}) {
    final g = target;
    const gap = SizedBox(height: 12);
    if (!lookupsOn) return [if (!scrolls) gap, const _LookupsOff()];
    return [
      if (!scrolls) gap,
      if (state.error != null) ...[_error(), gap],
      if (g != null) ...[
        _HeroCard(g: g, self: isSelf),
        gap,
        _pills(height: 32),
        gap,
        _DetailList(rows: _rows(g, full: true), rowHeight: 44),
        if (scrolls) const Spacer() else gap,
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: PulseButton(
                label: 'Ping this',
                icon: PulseIcons.pulse,
                style: PulseButtonStyle.tonal,
                expand: true,
                onPressed: onPing,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: PulseButton(label: 'Trace route', icon: PulseIcons.route, expand: true, onPressed: onTrace),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _SourceNote(source: g.source),
      ] else if (state.loading)
        _HeroCard.locating(query: state.query)
      else if (state.error == null)
        PulseCard(child: _Idle(onMyIp: onMyIp)),
    ];
  }

  // ---- Shared bits ---------------------------------------------------------

  Widget _error() {
    final e = state.error!;
    final title = e.contains('private')
        ? 'Private address'
        : e.startsWith('DNS')
        ? 'Could not resolve ${state.query}'
        : 'Lookup failed';
    return PulseErrorBanner(title: title, message: e, onRetry: state.query.isEmpty ? onMyIp : onLocate);
  }

  Widget _pills({required double height}) {
    final km = state.distanceKm;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        if (isSelf)
          PulsePill('This device', tone: PulsePillTone.lime, height: height)
        else if (km != null)
          PulsePill('${NumberFormat('#,###').format(km.round())} km', tone: PulsePillTone.lime, height: height),
        if (state.rttMs != null)
          PulsePill('${fmtMs(state.rttMs)} ms', tone: PulsePillTone.lavender, height: height)
        else if (!isSelf)
          PulsePill('No ping reply', tone: PulsePillTone.outline, height: height),
        if (state.hops != null) PulsePill('${state.hops} hops', height: height),
      ],
    );
  }
}

String? _nonBlank(Iterable<String?> values) {
  for (final v in values) {
    if (v != null && v.trim().isNotEmpty) return v.trim();
  }
  return null;
}

String _place(GeoInfo g) => _nonBlank([g.city, g.country, g.countryCode]) ?? g.ip;

String _meta(GeoInfo g) => [
  _nonBlank([g.countryCode, g.country]),
  _nonBlank([g.timezone]),
  utcOffsetLabel(g.timezone),
].whereType<String>().join(' · ');

String _coords(GeoInfo g) {
  if (g.lat == null || g.lon == null) return '—';
  String c(double v, String pos, String neg) => '${v.abs().toStringAsFixed(4)} ${v >= 0 ? pos : neg}';
  return '${c(g.lat!, 'N', 'S')}, ${c(g.lon!, 'E', 'W')}';
}

String _hosting(GeoInfo g) => switch ((g.hosting, g.mobile)) {
  (null, _) => '—',
  (true, _) => 'Yes · datacenter',
  (false, true) => 'No · mobile network',
  _ => 'No · residential',
};

/// (label, value, copy button).
List<(String, String, bool)> _rows(GeoInfo g, {required bool full}) {
  final city = [g.city, g.region].whereType<String>().where((v) => v.trim().isNotEmpty).toSet().join(', ');
  return [
    ('IP', g.ip, true),
    if (full) ('City', city.isEmpty ? '—' : city, false),
    ('Org', _nonBlank([g.org, g.isp]) ?? '—', false),
    ('ASN', _nonBlank([g.asn]) ?? '—', false),
    ('Coordinates', _coords(g), g.lat != null),
    if (full) ('Postal', _nonBlank([g.postal]) ?? '—', false),
    ('Hosting', _hosting(g), false),
  ];
}

class _PlaceTitle extends StatelessWidget {
  const _PlaceTitle({required this.g});
  final GeoInfo g;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(_place(g), maxLines: 1, style: context.type.headlineLarge),
      ),
      Text(
        _meta(g),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: context.type.bodyMedium!.copyWith(color: context.colors.onSurfaceVariant),
      ),
    ],
  );
}

/// Pink "Located in" hero with a slowly spinning decorative cookie.
class _HeroCard extends StatelessWidget {
  const _HeroCard({required GeoInfo this.g, this.self = false}) : query = null;
  const _HeroCard.locating({required String this.query}) : g = null, self = false;

  final GeoInfo? g;
  final String? query;
  final bool self;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fg = c.onPrimaryFixed;
    return Semantics(
      container: true,
      liveRegion: g == null,
      child: Container(
        decoration: BoxDecoration(color: c.primaryFixedDim, borderRadius: BorderRadius.circular(32)),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned(
              right: -40,
              top: -50,
              child: ExcludeSemantics(
                child: PulseShapeBox(
                  shape: PulseShape.cookie12,
                  color: c.primaryFixed.withValues(alpha: .6),
                  size: 170,
                  spin: PulseMotion.heroSpin,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (g == null) ...[PulseLiveDot(color: fg, size: 7), const SizedBox(width: 8)],
                      Flexible(
                        child: Text(
                          g == null ? 'Locating' : (self ? 'You are in' : 'Located in'),
                          style: context.type.labelLarge!.copyWith(color: fg, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      g == null ? query! : _place(g!),
                      maxLines: 1,
                      style: pulseText(50, 900, wdth: 125, height: 1.05, tracking: -.02).copyWith(color: fg),
                    ),
                  ),
                  Text(
                    g == null ? 'Resolving and looking up the address…' : _meta(g!),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.type.bodyMedium!.copyWith(color: fg),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Segmented key/value rows. Long-press any row to copy its value.
class _DetailList extends StatelessWidget {
  const _DetailList({required this.rows, required this.rowHeight});
  final List<(String, String, bool)> rows;
  final double rowHeight;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final n = rows.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, (k, v, copy)) in rows.indexed) ...[
          if (i > 0) const SizedBox(height: PulseLayout.seam),
          Semantics(
            label: '$k: $v',
            excludeSemantics: !copy,
            child: Material(
              color: c.surfaceContainer,
              borderRadius: segmentedRadius(i, n),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onLongPress: v == '—' ? null : () => _copy(context, v),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: rowHeight),
                  child: Padding(
                    padding: EdgeInsets.only(left: 16, right: copy ? 2 : 16),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 96,
                          child: Text(k, style: context.type.bodyMedium!.copyWith(color: c.onSurfaceVariant)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            v,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                            style: context.type.titleSmall!.copyWith(color: c.onSurface),
                          ),
                        ),
                        if (copy) PulseCopyButton(text: v, label: 'Copy $k'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  static void _copy(BuildContext context, String v) {
    Clipboard.setData(ClipboardData(text: v));
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('Copied $v'), duration: const Duration(seconds: 2)));
  }
}

class _SourceNote extends StatelessWidget {
  const _SourceNote({required this.source});
  final String source;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: Text(
      'Data: ${source.isEmpty ? 'ip-api.com' : source} · Map: Natural Earth',
      style: context.type.labelMedium!.copyWith(color: context.colors.onSurfaceVariant, fontWeight: FontWeight.w500),
    ),
  );
}

class _Locating extends StatelessWidget {
  const _Locating({required this.query});
  final String query;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          PulseLiveDot(color: context.colors.primary, size: 8),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              query.isEmpty ? 'Finding your public IP…' : 'Locating $query…',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.type.titleSmall,
            ),
          ),
        ],
      ),
    ),
  );
}

class _Idle extends StatelessWidget {
  const _Idle({required this.onMyIp});
  final VoidCallback onMyIp;

  @override
  Widget build(BuildContext context) => PulseEmptyState(
    title: 'Where does it live?',
    message: 'Look up a domain or IP to see its location, distance from you, network owner and hosting type.',
    icon: PulseIcons.pin,
    shape: PulseShape.cookie9,
    size: 96,
    action: PulseButton(
      label: 'Locate my IP',
      icon: PulseIcons.globe,
      style: PulseButtonStyle.tonal,
      onPressed: onMyIp,
    ),
  );
}

class _LookupsOff extends StatelessWidget {
  const _LookupsOff();

  @override
  Widget build(BuildContext context) => PulseCard(
    child: PulseEmptyState(
      title: 'Public IP lookups are off',
      message:
          'Geo IP sends the address you look up to ip-api.com (or ipinfo.io). '
          'Turn on Public IP lookups in Settings › Privacy to use it.',
      icon: PulseIcons.shield,
      shape: PulseShape.clover4,
      size: 96,
      action: PulseButton(
        label: 'Open Settings',
        icon: PulseIcons.settings,
        style: PulseButtonStyle.tonal,
        onPressed: () => context.go(Routes.settings),
      ),
    ),
  );
}

bool _lookupsOffError(String error) => error.contains('turned off');
