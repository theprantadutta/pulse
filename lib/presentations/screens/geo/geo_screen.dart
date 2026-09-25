import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/format.dart';
import '../../../core/widgets/wire/wire.dart';
import '../../../core/widgets/wire/wire_page.dart';
import '../../../providers/geo_provider.dart';
import '../../../providers/ping_provider.dart';
import '../../../services/net/geo_ip.dart';
import '../../navigation/destinations.dart';

/// 06 — Geo IP.
class GeoScreen extends ConsumerStatefulWidget {
  const GeoScreen({super.key, this.initialTarget});
  final String? initialTarget;

  @override
  ConsumerState<GeoScreen> createState() => _GeoScreenState();
}

class _GeoScreenState extends ConsumerState<GeoScreen> {
  late final _query = TextEditingController(
    text: widget.initialTarget ?? ref.read(geoProvider).query,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final geo = ref.read(geoProvider.notifier);
      if (widget.initialTarget != null) {
        geo.locate(widget.initialTarget!);
      } else if (ref.read(geoProvider).target == null && !ref.read(geoProvider).loading) {
        geo.locateMe();
      }
    });
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _locate() => ref.read(geoProvider.notifier).locate(_query.text);

  Future<void> _myIp() async {
    await ref.read(geoProvider.notifier).locateMe();
    _query.text = ref.read(geoProvider).query;
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(geoProvider);
    final w = context.wire;
    return WireAdaptive(
      mobile: (context) => WireMobilePage(
        header: WireMobileHeader(
          title: 'Geo IP',
          onBack: GoRouter.maybeOf(context)?.canPop() == true ? () => context.pop() : null,
          trailing: WirePressable(
            onTap: _myIp,
            tone: WireTone.ink,
            semanticLabel: 'My IP',
            builder: (context, c, st) => Container(
              color: c.bg,
              height: WireLayout.mobileHeader,
              alignment: Alignment.center,
              child: Text('MY IP', style: WireType.label(12).copyWith(color: st.isEmpty ? w.signal : c.fg)),
            ),
          ),
        ),
        body: ListView(
          padding: EdgeInsets.zero,
          children: [
            Container(
              height: 50,
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: w.ink, width: kWireBorder))),
              child: WireTargetField(
                controller: _query,
                prefix: 'LOOKUP>',
                hint: 'domain or IP',
                fontSize: 17,
                onSubmitted: (_) => _locate(),
              ),
            ),
            Container(
              height: 220,
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: w.ink, width: kWireBorder))),
              child: _GeoMap(state: s, compact: true),
            ),
            if (s.error != null)
              WireErrorBlock(title: s.error!.contains('private') ? 'PRIVATE' : 'UNREACHABLE', reason: s.error!, size: 56)
            else if (s.target != null) ...[
              Container(
                color: w.signal,
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(_placeTitle(s.target!), style: WireType.display(48, width: 65).copyWith(color: w.onSignal)),
                    ),
                    Text(
                      [
                        if (s.distanceKm != null) '${NumberFormat('#,###').format(s.distanceKm!.round())} KM AWAY',
                        if (s.rttMs != null) '${fmtMs(s.rttMs)} MS',
                      ].join(' · '),
                      style: WireType.label().copyWith(color: w.onSignal),
                    ),
                  ],
                ),
              ),
              const WireRule(),
              for (final (k, v) in _rows(s.target!, mobile: true)) _KvRow(k: k, v: v, dense: true),
            ] else if (s.loading)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text('Locating ${s.query}…', style: WireType.body(13)),
              ),
          ],
        ),
        action: WireButton.bar(label: 'Locate', busy: s.loading, onPressed: s.loading ? null : _locate),
      ),
      desktop: (context) => WireDesktopPage(
        panelWidth: 380,
        topBar: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: WireTargetField(
                controller: _query,
                prefix: 'LOOKUP>',
                hint: 'domain or IP',
                onSubmitted: (_) => _locate(),
                trailing: s.resolvedIp != null && s.resolvedIp != s.query
                    ? Text('→ ${s.resolvedIp}', style: WireType.body(13).copyWith(color: w.text3))
                    : null,
              ),
            ),
            const WireVRule(),
            WireCell(
              onTap: _myIp,
              sides: WireSides.onlyRight,
              alignment: Alignment.center,
              child: Text('MY IP', style: WireType.data(13)),
            ),
            WireButton(
              label: 'Locate',
              variant: WireButtonVariant.inverse,
              bordered: false,
              busy: s.loading,
              fontSize: 17,
              height: WireLayout.topBar,
              padding: const EdgeInsets.symmetric(horizontal: 28),
              onPressed: s.loading ? null : _locate,
            ),
          ],
        ),
        body: Stack(
          children: [
            Positioned.fill(child: _GeoMap(state: s)),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: w.background,
                  border: Border(top: BorderSide(color: w.ink, width: kWireBorder)),
                ),
                child: WireSplitRow(
                  children: [
                    WireStat(
                      label: 'Distance',
                      value: s.distanceKm == null ? '—' : '${NumberFormat('#,###').format(s.distanceKm!.round())} KM',
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                    ),
                    WireStat(
                      label: 'RTT',
                      value: s.rttMs == null ? '—' : '${fmtMs(s.rttMs)} MS',
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                    ),
                    WireStat(
                      label: 'Hops',
                      value: s.hops?.toString() ?? '—',
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        panel: _Panel(state: s),
      ),
    );
  }
}

String _placeTitle(GeoInfo g) => (g.city ?? g.country ?? g.countryCode ?? g.ip).toUpperCase();

List<(String, String)> _rows(GeoInfo g, {bool mobile = false}) {
  String coord(double? v, String pos, String neg) =>
      v == null ? '—' : '${v.abs().toStringAsFixed(mobile ? 2 : 4)} ${v >= 0 ? pos : neg}';
  return [
    ('IP', g.ip),
    if (!mobile) ('City', [g.city, g.region].whereType<String>().toSet().join(', ')),
    ('Org', g.org ?? g.isp ?? '—'),
    ('ASN', g.asn ?? '—'),
    if (mobile) ('Timezone', utcOffsetLabel(g.timezone) ?? g.timezone ?? '—'),
    ('Coords', g.lat == null ? '—' : '${coord(g.lat, 'N', 'S')}, ${coord(g.lon, 'E', 'W')}'),
    if (!mobile) ('Postal', g.postal ?? '—'),
    if (!mobile)
      (
        'Hosting',
        g.hosting == null
            ? '—'
            : g.hosting!
            ? 'Yes · datacenter'
            : g.mobile == true
            ? 'No · mobile network'
            : 'No · residential',
      ),
  ];
}

class _KvRow extends StatelessWidget {
  const _KvRow({required this.k, required this.v, this.dense = false});
  final String k;
  final String v;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return WireRow(
      padding: EdgeInsets.symmetric(horizontal: dense ? 14 : 20, vertical: dense ? 10 : 11),
      minHeight: 40,
      child: Row(
        children: [
          Text(k.toUpperCase(), style: WireType.label()),
          const SizedBox(width: 16),
          Expanded(
            child: SelectableText(
              v,
              textAlign: TextAlign.right,
              maxLines: 1,
              style: WireType.data(dense ? 13 : 14),
            ),
          ),
        ],
      ),
    );
  }
}

class _Panel extends ConsumerWidget {
  const _Panel({required this.state});
  final GeoState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final w = context.wire;
    final s = state;
    final g = s.target;
    if (s.error != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          WireErrorBlock(
            title: s.error!.contains('private') ? 'PRIVATE' : 'UNREACHABLE',
            reason: s.error!,
            size: 64,
          ),
        ],
      );
    }
    if (g == null) {
      return Center(
        child: Text(s.loading ? 'Locating ${s.query}…' : 'Look up a domain or IP.', style: WireType.body(13).copyWith(color: w.text3)),
      );
    }
    final meta = [g.countryCode, g.timezone?.toUpperCase(), utcOffsetLabel(g.timezone)].whereType<String>().join(' · ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          color: w.signal,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('LOCATED IN', style: WireType.label().copyWith(color: w.onSignal)),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(_placeTitle(g), style: WireType.display(54, width: 65, height: 0.95).copyWith(color: w.onSignal)),
              ),
              Text(meta, style: WireType.label(12).copyWith(color: w.onSignal)),
            ],
          ),
        ),
        const WireRule(),
        Expanded(
          child: ListView(
            children: [
              for (final (k, v) in _rows(g)) _KvRow(k: k, v: v),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
                child: Text('via ${g.source}', style: WireType.body(11).copyWith(color: w.text3)),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(border: Border(top: BorderSide(color: w.ink, width: kWireBorder))),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: WireButton(
                    label: 'Ping this',
                    bordered: false,
                    sides: WireSides.onlyRight,
                    fontSize: 16,
                    height: 52,
                    onPressed: () async {
                      await ref.read(pingBoardProvider.notifier).start(s.query, name: g.city);
                      if (context.mounted) context.go(Routes.ping);
                    },
                  ),
                ),
                Expanded(
                  child: WireButton(
                    label: 'Trace route',
                    bordered: false,
                    fontSize: 16,
                    height: 52,
                    onPressed: () => context.go('${Routes.traceroute}?target=${Uri.encodeComponent(s.query)}'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Grayscale OSM map with square markers; inverted in the Ink theme.
class _GeoMap extends StatefulWidget {
  const _GeoMap({required this.state, this.compact = false});
  final GeoState state;
  final bool compact;

  @override
  State<_GeoMap> createState() => _GeoMapState();
}

class _GeoMapState extends State<_GeoMap> {
  final _controller = MapController();
  bool _ready = false;

  LatLng? _point(GeoInfo? g) => g?.lat == null || g?.lon == null ? null : LatLng(g!.lat!, g.lon!);

  void _fit() {
    if (!_ready) return;
    final a = _point(widget.state.me), b = _point(widget.state.target);
    final pts = [?a, ?b];
    if (pts.isEmpty) return;
    if (pts.length == 1 || (a != null && b != null && a == b)) {
      _controller.move(pts.first, 5);
      return;
    }
    _controller.fitCamera(
      CameraFit.coordinates(
        coordinates: pts,
        padding: EdgeInsets.fromLTRB(60, 70, 60, widget.compact ? 40 : 160),
        maxZoom: 9,
      ),
    );
  }

  @override
  void didUpdateWidget(_GeoMap old) {
    super.didUpdateWidget(old);
    if (old.state.target != widget.state.target || old.state.me != widget.state.me) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fit());
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = context.wire;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final gray = <double>[
      0.2126, 0.7152, 0.0722, 0, 0,
      0.2126, 0.7152, 0.0722, 0, 0,
      0.2126, 0.7152, 0.0722, 0, 0,
      0, 0, 0, 1, 0,
    ];
    final grayInverted = <double>[
      -0.2126, -0.7152, -0.0722, 0, 235,
      -0.2126, -0.7152, -0.0722, 0, 235,
      -0.2126, -0.7152, -0.0722, 0, 235,
      0, 0, 0, 1, 0,
    ];
    final me = _point(widget.state.me);
    final target = _point(widget.state.target);
    Widget label(String text, {required bool inverse}) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: inverse ? w.ink : w.background,
        border: Border.all(color: w.ink, width: kWireBorder),
      ),
      child: Text(text, style: WireType.label().copyWith(color: inverse ? w.background : w.ink, height: 1.2)),
    );
    return Stack(
      children: [
        FlutterMap(
          mapController: _controller,
          options: MapOptions(
            initialCenter: target ?? me ?? const LatLng(20, 0),
            initialZoom: 2,
            minZoom: 1,
            maxZoom: 16,
            backgroundColor: w.mutedRow,
            onMapReady: () {
              _ready = true;
              _fit();
            },
            interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.pranta.pulse',
              maxNativeZoom: 19,
              tileBuilder: (context, tile, _) => ColorFiltered(
                colorFilter: ColorFilter.matrix(dark ? grayInverted : gray),
                child: tile,
              ),
            ),
            if (me != null && target != null && me != target)
              PolylineLayer(
                polylines: [Polyline(points: [me, target], strokeWidth: kWireBorder, color: w.ink)],
              ),
            MarkerLayer(
              markers: [
                if (me != null) ...[
                  Marker(point: me, width: 16, height: 16, child: Container(color: w.ink)),
                  Marker(
                    point: me,
                    width: 80,
                    height: 36,
                    alignment: Alignment.bottomCenter,
                    child: Align(alignment: Alignment.bottomCenter, child: label('YOU', inverse: false)),
                  ),
                ],
                if (target != null && target != me) ...[
                  Marker(
                    point: target,
                    width: widget.compact ? 18 : 22,
                    height: widget.compact ? 18 : 22,
                    child: Container(
                      decoration: BoxDecoration(color: w.signal, border: Border.all(color: w.ink, width: kWireBorder)),
                    ),
                  ),
                  if (!widget.compact)
                    Marker(
                      point: target,
                      width: 90,
                      height: 40,
                      alignment: Alignment.bottomCenter,
                      child: Align(alignment: Alignment.bottomCenter, child: label('TARGET', inverse: true)),
                    ),
                ],
              ],
            ),
          ],
        ),
        Positioned(
          top: 8,
          right: 8,
          child: GestureDetector(
            onTap: () => launchUrl(Uri.parse('https://www.openstreetmap.org/copyright')),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: w.background, border: Border.all(color: w.ink, width: 1)),
              child: Text('© OpenStreetMap contributors', style: WireType.body(10).copyWith(color: w.ink, height: 1.2)),
            ),
          ),
        ),
      ],
    );
  }
}
