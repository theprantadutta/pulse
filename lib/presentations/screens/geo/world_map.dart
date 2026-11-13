import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/widgets/pulse/pulse.dart';

/// Offline vector world map (land + country borders) for Geo IP.
///
/// Data: `assets/data/world_map.bin`, built from Natural Earth 1:50m (public
/// domain) via the world-atlas TopoJSON package (ISC). Format, little endian:
/// `'PWM1'`, u32 land rings, u32 border lines, then per record a u32 point count
/// followed by `(i16 lon, i16 lat)` pairs scaled by 32767/200 and 32767/90.
/// Rings that cross the antimeridian are unwrapped (lon may run past 180), so
/// the painter draws neighbouring world copies.
class WorldMap {
  WorldMap._(this.land, this.borders);

  /// Paths in Web Mercator world units: x and y in 0..[size].
  final Path land;
  final Path borders;

  static const double size = 256;
  static const asset = 'assets/data/world_map.bin';

  static WorldMap? _instance;
  static Future<WorldMap>? _loading;

  /// The parsed map if it has been loaded already.
  static WorldMap? get cached => _instance;

  /// Loads and parses the asset once; later calls reuse it.
  static Future<WorldMap> load([AssetBundle? bundle]) {
    if (_instance != null) return Future.value(_instance);
    return _loading ??= (bundle ?? rootBundle).load(asset).then((data) => _instance = parse(data)).whenComplete(() {
      _loading = null;
    });
  }

  /// Seeds the cache (tests read the asset from disk).
  static void prime(ByteData data) => _instance = parse(data);

  static WorldMap parse(ByteData data) {
    if (data.lengthInBytes < 12 ||
        data.getUint8(0) != 0x50 ||
        data.getUint8(1) != 0x57 ||
        data.getUint8(2) != 0x4D ||
        data.getUint8(3) != 0x31) {
      throw const FormatException('Not a Pulse world map');
    }
    final landCount = data.getUint32(4, Endian.little);
    final borderCount = data.getUint32(8, Endian.little);
    var o = 12;
    final land = Path()..fillType = PathFillType.evenOdd;
    final borders = Path();
    for (var r = 0; r < landCount + borderCount; r++) {
      final n = data.getUint32(o, Endian.little);
      o += 4;
      final path = r < landCount ? land : borders;
      for (var i = 0; i < n; i++) {
        final lon = data.getInt16(o, Endian.little) / 32767 * 200;
        final lat = data.getInt16(o + 2, Endian.little) / 32767 * 90;
        o += 4;
        final p = project(lat, lon);
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      if (r < landCount) path.close();
    }
    return WorldMap._(land, borders);
  }

  static const double maxLat = 85.05112878;

  /// Web Mercator, world units.
  static Offset project(double lat, double lon) {
    final phi = lat.clamp(-maxLat, maxLat) * math.pi / 180;
    final x = (lon + 180) / 360 * size;
    final y = (1 - math.log(math.tan(math.pi / 4 + phi / 2)) / math.pi) / 2 * size;
    return Offset(x, y);
  }
}

/// A point on the map with its label.
@immutable
class MapPoint {
  const MapPoint(this.lat, this.lon, this.label);
  final double lat, lon;
  final String label;

  @override
  bool operator ==(Object other) => other is MapPoint && other.lat == lat && other.lon == lon && other.label == label;

  @override
  int get hashCode => Object.hash(lat, lon, label);
}

/// Map card: sea, land and borders, the route arc from [you] to [target] with a
/// flowing dash and a travelling packet, a lime "You" marker and a spinning
/// pink cookie with a sonar on the target. The view fits both points; with
/// [interactive] it also pans and zooms (pinch, scroll, drag).
class GeoRouteMap extends StatefulWidget {
  const GeoRouteMap({super.key, this.you, this.target, this.interactive = false, this.radius = 28});

  final MapPoint? you;
  final MapPoint? target;
  final bool interactive;
  final double radius;

  @override
  State<GeoRouteMap> createState() => _GeoRouteMapState();
}

/// Centre in world units and scale in px per world unit.
typedef _View = ({Offset center, double scale});

class _GeoRouteMapState extends State<GeoRouteMap> with TickerProviderStateMixin {
  WorldMap? _map = WorldMap.cached;
  Object? _loadError;

  late final AnimationController _packet = AnimationController(vsync: this, duration: PulseMotion.packetTravel);
  late final AnimationController _sonar = AnimationController(vsync: this, duration: PulseMotion.sonar);
  late final AnimationController _fly = AnimationController(vsync: this, duration: PulseMotion.enter);

  Size _size = Size.zero;
  _View? _view; // current
  _View? _flyFrom, _flyTo;
  bool _userMoved = false;

  // Gesture state.
  double _startScale = 1;
  Offset _startFocal = Offset.zero;
  Offset _startCenter = Offset.zero;

  @override
  void initState() {
    super.initState();
    if (_map == null) {
      WorldMap.load().then(
        (m) {
          if (mounted) setState(() => _map = m);
        },
        onError: (Object e) {
          if (mounted) setState(() => _loadError = e);
        },
      );
    }
    _fly.addListener(() {
      final a = _flyFrom, b = _flyTo;
      if (a == null || b == null) return;
      final t = PulseMotion.emphasized.transform(_fly.value);
      setState(() {
        _view = (
          center: Offset.lerp(a.center, b.center, t)!,
          scale: math.exp(_lerp(math.log(a.scale), math.log(b.scale), t)),
        );
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncLoops();
  }

  @override
  void didUpdateWidget(GeoRouteMap old) {
    super.didUpdateWidget(old);
    if (old.you != widget.you || old.target != widget.target) {
      _userMoved = false;
      _refit(animate: true);
      _syncLoops();
    }
  }

  @override
  void dispose() {
    _packet.dispose();
    _sonar.dispose();
    _fly.dispose();
    super.dispose();
  }

  bool get _reduced => PulseMotion.reduced(context);

  void _syncLoops() {
    final route = widget.you != null && widget.target != null && _targetOffset() != null;
    if (_reduced) {
      _packet.stop();
      _sonar.stop();
      return;
    }
    if (route && !_packet.isAnimating) _packet.repeat();
    if (!route) _packet.stop();
    if (widget.target != null && !_sonar.isAnimating) _sonar.repeat();
    if (widget.target == null) _sonar.stop();
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  /// World position of [you], and of [target] shifted by a world width when
  /// the short way crosses the antimeridian.
  Offset? _youOffset() => widget.you == null ? null : WorldMap.project(widget.you!.lat, widget.you!.lon);

  Offset? _targetOffset() {
    final t = widget.target;
    if (t == null) return null;
    final p = WorldMap.project(t.lat, t.lon);
    final y = widget.you;
    if (y == null) return p;
    final d = t.lon - y.lon;
    if (d > 180) return p.translate(-WorldMap.size, 0);
    if (d < -180) return p.translate(WorldMap.size, 0);
    return p;
  }

  double get _minScale => math.max(_size.width, _size.height) / WorldMap.size;
  static const double _maxScale = 4096;

  _View _fit() {
    final pts = [?_youOffset(), ?_targetOffset()];
    final w = _size.width, h = _size.height;
    if (pts.isEmpty) {
      // Whole world (cropped to the inhabited latitudes).
      return (center: WorldMap.project(20, 10), scale: _minScale);
    }
    if (pts.length == 1 || (pts[0] - pts[1]).distance < 1e-6) {
      // Regional zoom: about 2,500 km across.
      return (center: pts.first, scale: math.max(_minScale, 32.0 * math.min(w, h) / 360));
    }
    // Room for labels and the route's bulge.
    final padX = math.min(72.0, w * .18), padTop = math.min(64.0, h * .2), padBottom = math.min(48.0, h * .16);
    final rect = Rect.fromPoints(pts[0], pts[1]);
    final sx = (w - 2 * padX) / math.max(rect.width, 1e-6);
    final sy = (h - padTop - padBottom) / math.max(rect.height, 1e-6);
    final scale = math.min(sx, sy).clamp(_minScale, 512.0).toDouble();
    // Shift so the padding is asymmetric (labels sit above the markers).
    final center = rect.center + Offset(0, (padBottom - padTop) / 2 / scale);
    return (center: center, scale: scale);
  }

  void _refit({bool animate = false}) {
    if (_size.isEmpty) return;
    final to = _fit();
    if (!animate || _view == null || _reduced) {
      _fly.stop();
      _view = to;
      return;
    }
    _flyFrom = _view;
    _flyTo = to;
    _fly.forward(from: 0);
  }

  _View _clamp(_View v) {
    final scale = v.scale.clamp(_minScale, _maxScale).toDouble();
    // Keep the map covering the card vertically; x wraps freely.
    final halfH = _size.height / 2 / scale;
    final cy = halfH * 2 >= WorldMap.size ? WorldMap.size / 2 : v.center.dy.clamp(halfH, WorldMap.size - halfH);
    var cx = v.center.dx;
    cx = cx.clamp(-WorldMap.size * .5, WorldMap.size * 1.5).toDouble();
    return (center: Offset(cx, cy.toDouble()), scale: scale);
  }

  void _zoomAt(Offset focal, double factor) {
    final v = _view;
    if (v == null) return;
    final world = v.center + (focal - _size.center(Offset.zero)) / v.scale;
    final scale = (v.scale * factor).clamp(_minScale, _maxScale).toDouble();
    final center = world - (focal - _size.center(Offset.zero)) / scale;
    _fly.stop();
    setState(() {
      _userMoved = true;
      _view = _clamp((center: center, scale: scale));
    });
  }

  void _recenter() {
    setState(() => _userMoved = false);
    _refit(animate: true);
  }

  Offset _toScreen(Offset world, _View v) => (world - v.center) * v.scale + _size.center(Offset.zero);

  String get _semantics {
    final y = widget.you, t = widget.target;
    if (y != null && t != null) return 'Map: route from ${y.label} to ${t.label}';
    if (t != null) return 'Map: ${t.label}';
    if (y != null) return 'Map: ${y.label}';
    return 'World map';
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pulse;
    return Semantics(
      label: _semantics,
      image: true,
      excludeSemantics: !widget.interactive,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.radius),
        child: ColoredBox(
          color: p.mapSea,
          child: LayoutBuilder(
            builder: (context, box) {
              final size = box.biggest;
              if (size != _size) {
                final first = _size.isEmpty;
                _size = size;
                if (first || !_userMoved) {
                  _refit();
                } else {
                  _view = _clamp(_view!);
                }
              }
              final v = _view;
              if (v == null || _map == null) {
                return _loadError == null
                    ? const SizedBox.expand()
                    : Center(
                        child: Text(
                          'Map unavailable',
                          style: context.type.bodySmall!.copyWith(color: context.colors.onSurfaceVariant),
                        ),
                      );
              }
              final you = _youOffset(), target = _targetOffset();
              final a = you == null ? null : _toScreen(you, v);
              final b = target == null ? null : _toScreen(target, v);
              Widget stack = Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  Positioned.fill(
                    child: RepaintBoundary(
                      child: _LandImage(
                        painter: _LandPainter(map: _map!, view: v, land: p.mapLand, border: p.mapBorder),
                      ),
                    ),
                  ),
                  if (a != null && b != null)
                    Positioned.fill(
                      child: RepaintBoundary(
                        child: CustomPaint(
                          painter: _RoutePainter(
                            from: a,
                            to: b,
                            color: context.colors.primary,
                            progress: _packet,
                            animate: !_reduced,
                          ),
                        ),
                      ),
                    ),
                  if (a != null) ..._youMarker(context, a),
                  if (b != null) ..._targetMarker(context, b, a),
                  if (widget.interactive && _userMoved)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: PulseIconButton(
                        icon: PulseIcons.refresh,
                        tooltip: 'Fit route',
                        style: PulseIconButtonStyle.neutral,
                        onPressed: _recenter,
                      ),
                    ),
                ],
              );
              if (widget.interactive) {
                stack = Listener(
                  onPointerSignal: (e) {
                    if (e is PointerScrollEvent) {
                      _zoomAt(e.localPosition, math.pow(2, -e.scrollDelta.dy / 240).toDouble());
                    }
                  },
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onDoubleTapDown: (d) => _startFocal = d.localPosition,
                    onDoubleTap: () => _zoomAt(_startFocal, 2),
                    onScaleStart: (d) {
                      _fly.stop();
                      _startScale = _view!.scale;
                      _startFocal = d.localFocalPoint;
                      _startCenter = _view!.center;
                    },
                    onScaleUpdate: (d) {
                      final scale = (_startScale * d.scale).clamp(_minScale, _maxScale).toDouble();
                      final c = _size.center(Offset.zero);
                      // Keep the world point under the starting focal point under the finger.
                      final world = _startCenter + (_startFocal - c) / _startScale;
                      final center = world - (d.localFocalPoint - c) / scale;
                      setState(() {
                        _userMoved = true;
                        _view = _clamp((center: center, scale: scale));
                      });
                    },
                    child: stack,
                  ),
                );
              }
              return stack;
            },
          ),
        ),
      ),
    );
  }

  List<Widget> _youMarker(BuildContext context, Offset a) {
    final c = context.colors;
    // "labelLeft" = the label's left edge is pinned (label sits right of the dot).
    final labelLeft = a.dx + 140 < _size.width || a.dx < _size.width / 2;
    return [
      Positioned(
        left: a.dx - 9.5,
        top: a.dy - 9.5,
        child: Container(
          width: 19,
          height: 19,
          decoration: BoxDecoration(
            color: PulseBrand.lime,
            shape: BoxShape.circle,
            border: Border.all(color: PulseBrand.onLime, width: 3),
          ),
        ),
      ),
      Positioned(
        left: labelLeft ? a.dx + 14 : null,
        right: labelLeft ? null : _size.width - a.dx + 14,
        top: a.dy - 13,
        child: _MapLabel(widget.you!.label, bg: c.inverseSurface, fg: c.onInverseSurface),
      ),
    ];
  }

  List<Widget> _targetMarker(BuildContext context, Offset b, Offset? a) {
    final c = context.colors;
    const s = 30.0;
    final labelLeft = b.dx > 130 || b.dx > _size.width / 2;
    // Drop below the marker when it would collide with the "You" label.
    final below = (a != null && (a.dy - (b.dy - 33)).abs() < 34) || b.dy < 52;
    return [
      Positioned(
        left: b.dx - s / 2,
        top: b.dy - s / 2,
        child: IgnorePointer(
          child: SizedBox.square(
            dimension: s,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                if (!_reduced)
                  AnimatedBuilder(
                    animation: _sonar,
                    builder: (context, _) {
                      final t = Curves.easeOut.transform(_sonar.value);
                      return Transform.scale(
                        scale: 1 + 1.6 * t,
                        child: Container(
                          width: s - 8,
                          height: s - 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: c.primaryFixedDim.withValues(alpha: .6 * (1 - _sonar.value)),
                          ),
                        ),
                      );
                    },
                  ),
                PulseShapeBox(
                  shape: PulseShape.cookie9,
                  color: c.primaryFixedDim,
                  size: s,
                  spin: PulseMotion.smallSpin,
                ),
              ],
            ),
          ),
        ),
      ),
      Positioned(
        left: labelLeft ? null : b.dx + 10,
        right: labelLeft ? _size.width - b.dx - 4 : null,
        top: below ? b.dy + 20 : b.dy - 46,
        child: _MapLabel(widget.target!.label, bg: c.primaryFixedDim, fg: c.onPrimaryFixed),
      ),
    ];
  }
}

class _MapLabel extends StatelessWidget {
  const _MapLabel(this.text, {required this.bg, required this.fg});
  final String text;
  final Color bg, fg;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Container(
      constraints: const BoxConstraints(maxWidth: 200, minHeight: 26),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.3),
        style: pulseText(12, 700, wdth: 105, height: 1.3).copyWith(color: fg),
      ),
    ),
  );
}

/// The land and borders as a bitmap, redrawn only when the view, size or
/// colours change. Impeller has no raster cache, so drawing the coastline path
/// directly re-tessellated thousands of vertices on every frame of the sonar,
/// marker spin and route packet animations (~35 ms per frame on a Galaxy A24).
class _LandImage extends StatefulWidget {
  const _LandImage({required this.painter});
  final _LandPainter painter;

  @override
  State<_LandImage> createState() => _LandImageState();
}

class _LandImageState extends State<_LandImage> {
  ui.Image? _image;
  _LandPainter? _for;
  Size _size = Size.zero;
  double _dpr = 0;

  ui.Image? _imageFor(Size size, double dpr) {
    if (size.isEmpty) return null;
    final p = widget.painter;
    final stale = _image == null || size != _size || dpr != _dpr || _for == null || p.shouldRepaint(_for!);
    if (!stale) return _image;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(dpr);
    p.paint(canvas, size);
    final picture = recorder.endRecording();
    _image?.dispose();
    _image = picture.toImageSync((size.width * dpr).ceil(), (size.height * dpr).ceil());
    picture.dispose();
    _for = p;
    _size = size;
    _dpr = dpr;
    return _image;
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return LayoutBuilder(
      builder: (context, box) {
        final size = box.biggest;
        final image = _imageFor(size, dpr);
        if (image == null) return const SizedBox.expand();
        return RawImage(image: image, width: size.width, height: size.height, scale: dpr, fit: BoxFit.fill);
      },
    );
  }
}

class _LandPainter extends CustomPainter {
  _LandPainter({required this.map, required this.view, required this.land, required this.border});

  final WorldMap map;
  final _View view;
  final Color land, border;

  @override
  void paint(Canvas canvas, Size size) {
    final s = view.scale;
    final origin = size.center(Offset.zero) - view.center * s;
    // World copies needed to cover the card horizontally.
    final first = ((-origin.dx) / (WorldMap.size * s)).floor() - 1; // unwrapped rings reach past 180°
    final last = ((size.width - origin.dx) / (WorldMap.size * s)).floor();
    final fill = Paint()
      ..color = land
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    final stroke = Paint()
      ..color = border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1 / s
      ..strokeJoin = StrokeJoin.round;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    for (var k = first; k <= last && k <= first + 4; k++) {
      canvas.save();
      canvas.translate(origin.dx + k * WorldMap.size * s, origin.dy);
      canvas.scale(s);
      canvas.drawPath(map.land, fill);
      canvas.drawPath(map.borders, stroke);
      canvas.restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LandPainter old) =>
      old.map != map || old.view != view || old.land != land || old.border != border;
}

/// Quadratic bezier from [from] to [to], control point 90 px off the midpoint,
/// dashed 6/6 with a dash that flows toward the target, plus a packet dot that
/// travels the arc in 2.6 s (ease-in-out) and fades at both ends.
class _RoutePainter extends CustomPainter {
  _RoutePainter({
    required this.from,
    required this.to,
    required this.color,
    required this.progress,
    required this.animate,
  }) : super(repaint: progress);

  final Offset from, to;
  final Color color;
  final Animation<double> progress;
  final bool animate;

  @override
  void paint(Canvas canvas, Size size) {
    final d = to - from;
    final len = d.distance;
    if (len < 1) return;
    final mid = (from + to) / 2;
    final bulge = math.min(90.0, len * .45);
    final ctrl = mid + Offset(d.dy / len, -d.dx / len) * bulge;
    final path = Path()
      ..moveTo(from.dx, from.dy)
      ..quadraticBezierTo(ctrl.dx, ctrl.dy, to.dx, to.dy);
    final metric = path.computeMetrics().first;
    final t = animate ? progress.value : 0.0;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    final dashes = Path();
    // 48 px per loop = 4 dash periods, so the flow is seamless when t wraps.
    for (var s = (t * 48) % 12 - 12; s < metric.length; s += 12) {
      final a = math.max(0.0, s), b = math.min(metric.length, s + 6);
      if (b > a) dashes.addPath(metric.extractPath(a, b), Offset.zero);
    }
    canvas.drawPath(dashes, paint);
    if (!animate) return;
    final eased = Curves.easeInOut.transform(t);
    final tangent = metric.getTangentForOffset(metric.length * eased);
    if (tangent == null) return;
    final fade = (math.min(t, 1 - t) / .12).clamp(0.0, 1.0);
    canvas.drawCircle(tangent.position, 9, Paint()..color = color.withValues(alpha: .25 * fade));
    canvas.drawCircle(tangent.position, 5, Paint()..color = color.withValues(alpha: fade));
  }

  @override
  bool shouldRepaint(_RoutePainter old) =>
      old.from != from || old.to != to || old.color != color || old.animate != animate;
}
