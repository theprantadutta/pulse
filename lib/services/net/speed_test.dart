import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

/// A download server. Upload always goes to Cloudflare (the only public
/// endpoint that accepts arbitrary uploads).
class SpeedServer {
  const SpeedServer({
    required this.id,
    required this.name,
    required this.location,
    required this.downloadUrl,
    required this.pingUrl,
    this.lat,
    this.lon,
    this.chunked = false,
  });

  final String id;
  final String name;
  final String location;

  /// For Cloudflare, `{bytes}` is replaced with the chunk size.
  final String downloadUrl;
  final String pingUrl;
  final double? lat, lon;

  /// Download URL takes a byte count (Cloudflare) instead of a fixed file.
  final bool chunked;

  bool get isCloudflare => id == 'cf';
}

const kSpeedServers = <SpeedServer>[
  SpeedServer(
    id: 'cf',
    name: 'Cloudflare',
    location: 'nearest edge',
    downloadUrl: 'https://speed.cloudflare.com/__down?bytes={bytes}',
    pingUrl: 'https://speed.cloudflare.com/__down?bytes=0',
    chunked: true,
  ),
  SpeedServer(
    id: 'fsn1',
    name: 'Hetzner',
    location: 'Falkenstein, DE',
    downloadUrl: 'https://fsn1-speed.hetzner.com/1GB.bin',
    pingUrl: 'https://fsn1-speed.hetzner.com/',
    lat: 50.47,
    lon: 12.37,
  ),
  SpeedServer(
    id: 'nbg1',
    name: 'Hetzner',
    location: 'Nuremberg, DE',
    downloadUrl: 'https://nbg1-speed.hetzner.com/1GB.bin',
    pingUrl: 'https://nbg1-speed.hetzner.com/',
    lat: 49.45,
    lon: 11.08,
  ),
  SpeedServer(
    id: 'hel1',
    name: 'Hetzner',
    location: 'Helsinki, FI',
    downloadUrl: 'https://hel1-speed.hetzner.com/1GB.bin',
    pingUrl: 'https://hel1-speed.hetzner.com/',
    lat: 60.17,
    lon: 24.94,
  ),
  SpeedServer(
    id: 'ash',
    name: 'Hetzner',
    location: 'Ashburn, US',
    downloadUrl: 'https://ash-speed.hetzner.com/1GB.bin',
    pingUrl: 'https://ash-speed.hetzner.com/',
    lat: 39.04,
    lon: -77.49,
  ),
  SpeedServer(
    id: 'hil',
    name: 'Hetzner',
    location: 'Hillsboro, US',
    downloadUrl: 'https://hil-speed.hetzner.com/1GB.bin',
    pingUrl: 'https://hil-speed.hetzner.com/',
    lat: 45.52,
    lon: -122.99,
  ),
  SpeedServer(
    id: 'sin',
    name: 'Hetzner',
    location: 'Singapore, SG',
    downloadUrl: 'https://sin-speed.hetzner.com/1GB.bin',
    pingUrl: 'https://sin-speed.hetzner.com/',
    lat: 1.29,
    lon: 103.85,
  ),
];

enum SpeedPhase { idle, ping, download, upload, done }

class SpeedSample {
  const SpeedSample(this.mbps, {required this.upload});
  final double mbps;
  final bool upload;
}

class SpeedUpdate {
  const SpeedUpdate({
    required this.phase,
    this.liveMbps,
    this.pingMs,
    this.jitterMs,
    this.downMbps,
    this.upMbps,
    this.sample,
    this.progress = 0,
    this.colo,
  });

  final SpeedPhase phase;
  final double? liveMbps;
  final double? pingMs;
  final double? jitterMs;
  final double? downMbps;
  final double? upMbps;
  final SpeedSample? sample;

  /// 0–1 within the current phase.
  final double progress;

  /// Cloudflare data centre (IATA code) that served the test.
  final String? colo;
}

/// HTTP throughput test: latency, multi-stream download, multi-stream upload.
class SpeedTest {
  SpeedTest({
    this.downloadTime = const Duration(seconds: 10),
    this.uploadTime = const Duration(seconds: 8),
    this.streams = 4,
  });

  final Duration downloadTime;
  final Duration uploadTime;
  final int streams;

  bool _cancelled = false;
  final _clients = <HttpClient>[];

  void cancel() {
    _cancelled = true;
    for (final c in _clients) {
      c.close(force: true);
    }
    _clients.clear();
  }

  HttpClient _client() {
    final c = HttpClient()
      ..connectionTimeout = const Duration(seconds: 8)
      ..userAgent = 'Pulse speed test';
    _clients.add(c);
    return c;
  }

  /// Median HTTP round trip to [server]'s ping URL (reuses one connection).
  Future<double?> latency(SpeedServer server, {int samples = 5}) async {
    final c = _client();
    final times = <double>[];
    try {
      for (var i = 0; i < samples && !_cancelled; i++) {
        final sw = Stopwatch()..start();
        final req = await c.getUrl(Uri.parse(server.pingUrl));
        final res = await req.close();
        await res.drain<void>();
        times.add(sw.elapsedMicroseconds / 1000);
      }
    } on Object {
      return null;
    }
    if (times.length < 2) return times.firstOrNull;
    // The first request carries the TCP/TLS handshake.
    final warm = times.sublist(1)..sort();
    return warm[warm.length ~/ 2];
  }

  /// Picks the lowest-latency server.
  Future<(SpeedServer, double?)> autoSelect() async {
    // Sequential so the probes do not compete for the same uplink.
    final results = <(SpeedServer, double?)>[];
    for (final s in kSpeedServers) {
      results.add((s, await latency(s, samples: 4)));
    }
    final ok = results.where((r) => r.$2 != null).toList()..sort((a, b) => a.$2!.compareTo(b.$2!));
    return ok.isEmpty ? (kSpeedServers.first, null) : ok.first;
  }

  Future<String?> cloudflareColo() async {
    try {
      final c = _client();
      final req = await c.getUrl(Uri.parse('https://speed.cloudflare.com/cdn-cgi/trace'));
      final body = await (await req.close()).transform(const SystemEncoding().decoder).join();
      return RegExp(r'^colo=(\w+)$', multiLine: true).firstMatch(body)?.group(1);
    } on Object {
      return null;
    }
  }

  Stream<SpeedUpdate> run(SpeedServer server) async* {
    _cancelled = false;
    final colo = server.isCloudflare ? await cloudflareColo() : null;

    // 1 — latency and jitter over 10 sequential requests.
    yield SpeedUpdate(phase: SpeedPhase.ping, colo: colo);
    final c = _client();
    final times = <double>[];
    for (var i = 0; i < 11 && !_cancelled; i++) {
      final sw = Stopwatch()..start();
      try {
        final res = await (await c.getUrl(Uri.parse(server.pingUrl))).close();
        await res.drain<void>();
        if (i > 0) times.add(sw.elapsedMicroseconds / 1000);
      } on Object {
        // Count as a lost sample.
      }
      yield SpeedUpdate(phase: SpeedPhase.ping, progress: i / 10, colo: colo);
    }
    if (_cancelled) return;
    if (times.isEmpty) throw const SocketException('Speed test server unreachable');
    final sorted = List.of(times)..sort();
    final ping = sorted[sorted.length ~/ 2];
    var jitter = 0.0;
    for (var i = 1; i < times.length; i++) {
      jitter += (times[i] - times[i - 1]).abs();
    }
    jitter = times.length > 1 ? jitter / (times.length - 1) : 0;
    yield SpeedUpdate(phase: SpeedPhase.download, pingMs: ping, jitterMs: jitter, colo: colo);

    // 2 — download.
    double? down;
    await for (final u in _measure(upload: false, server: server)) {
      down = u.$2;
      yield SpeedUpdate(
        phase: SpeedPhase.download,
        liveMbps: u.$1,
        pingMs: ping,
        jitterMs: jitter,
        sample: SpeedSample(u.$1, upload: false),
        progress: u.$3,
        colo: colo,
      );
    }
    if (_cancelled) return;

    // 3 — upload (Cloudflare).
    double? up;
    await for (final u in _measure(upload: true, server: server)) {
      up = u.$2;
      yield SpeedUpdate(
        phase: SpeedPhase.upload,
        liveMbps: u.$1,
        pingMs: ping,
        jitterMs: jitter,
        downMbps: down,
        sample: SpeedSample(u.$1, upload: true),
        progress: u.$3,
        colo: colo,
      );
    }
    if (_cancelled) return;
    yield SpeedUpdate(
      phase: SpeedPhase.done,
      pingMs: ping,
      jitterMs: jitter,
      downMbps: down,
      upMbps: up,
      progress: 1,
      colo: colo,
    );
    for (final c in _clients) {
      c.close(force: true);
    }
    _clients.clear();
  }

  /// Emits (instant Mbps, overall Mbps, progress) every 250 ms.
  Stream<(double, double, double)> _measure({required bool upload, required SpeedServer server}) async* {
    final duration = upload ? uploadTime : downloadTime;
    var bytes = 0;
    final sw = Stopwatch()..start();
    var stop = false;
    final workers = <Future<void>>[];
    // Ignore the first second (TCP slow start) in the final figure.
    var warmBytes = 0;
    var warmAt = 0;

    Future<void> downloadWorker() async {
      final c = _client();
      while (!stop && !_cancelled) {
        try {
          final url = server.chunked ? server.downloadUrl.replaceFirst('{bytes}', '25000000') : server.downloadUrl;
          final res = await (await c.getUrl(Uri.parse(url))).close();
          await for (final chunk in res) {
            bytes += chunk.length;
            if (stop || _cancelled) break;
          }
        } on Object {
          if (stop || _cancelled) return;
          await Future<void>.delayed(const Duration(milliseconds: 200));
        }
      }
    }

    Future<void> uploadWorker() async {
      final c = _client();
      final chunk = Uint8List(64 * 1024);
      final rnd = math.Random();
      for (var i = 0; i < chunk.length; i++) {
        chunk[i] = rnd.nextInt(256);
      }
      while (!stop && !_cancelled) {
        try {
          final req = await c.postUrl(Uri.parse('https://speed.cloudflare.com/__up'));
          const total = 20 * 1024 * 1024;
          req.contentLength = total;
          req.headers.contentType = ContentType.binary;
          var sent = 0;
          while (sent < total && !stop && !_cancelled) {
            final n = math.min(chunk.length, total - sent);
            req.add(n == chunk.length ? chunk : chunk.sublist(0, n));
            await req.flush();
            sent += n;
            bytes += n;
          }
          if (stop || _cancelled) {
            req.abort();
            return;
          }
          await (await req.close()).drain<void>();
        } on Object {
          if (stop || _cancelled) return;
          await Future<void>.delayed(const Duration(milliseconds: 200));
        }
      }
    }

    for (var i = 0; i < streams; i++) {
      workers.add(upload ? uploadWorker() : downloadWorker());
    }

    var lastBytes = 0;
    var lastMs = 0;
    while (sw.elapsed < duration && !_cancelled) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      final ms = sw.elapsedMilliseconds;
      if (warmAt == 0 && ms >= 1000) {
        warmAt = ms;
        warmBytes = bytes;
      }
      final instant = (bytes - lastBytes) * 8 / ((ms - lastMs) / 1000) / 1e6;
      final overall = warmAt == 0 ? instant : (bytes - warmBytes) * 8 / ((ms - warmAt) / 1000) / 1e6;
      lastBytes = bytes;
      lastMs = ms;
      yield (instant, overall, ms / duration.inMilliseconds);
    }
    stop = true;
    for (final c in List.of(_clients)) {
      c.close(force: true);
    }
    _clients.clear();
    await Future.wait(workers).timeout(const Duration(seconds: 2), onTimeout: () => const []);
  }
}

/// Non-linear gauge position for 0 / 50 / 100 / 250 / 500+ Mbps.
double gaugeFraction(double mbps) {
  const stops = [0.0, 50, 100, 250, 500];
  if (mbps <= 0) return 0;
  for (var i = 1; i < stops.length; i++) {
    if (mbps <= stops[i]) {
      final t = (mbps - stops[i - 1]) / (stops[i] - stops[i - 1]);
      return (i - 1 + t) / (stops.length - 1);
    }
  }
  return 1;
}
