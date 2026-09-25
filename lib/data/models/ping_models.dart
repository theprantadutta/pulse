import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'app_settings.dart';

@immutable
class PingParams {
  const PingParams({
    this.count = 0,
    this.intervalMs = 1000,
    this.timeoutSec = 5,
    this.packetSize = 56,
    this.ipVersion = IpVersionPref.auto,
  });

  factory PingParams.fromSettings(AppSettings s) => PingParams(
    count: s.pingCount,
    intervalMs: s.pingIntervalMs,
    timeoutSec: s.pingTimeoutSec,
    packetSize: s.packetSize,
    ipVersion: s.ipVersion,
  );

  /// 0 = continuous.
  final int count;
  final int intervalMs;
  final int timeoutSec;
  final int packetSize;
  final IpVersionPref ipVersion;

  static const counts = [4, 10, 50, 0];
  static const intervals = [200, 500, 1000, 2000];
  static const timeouts = [1, 2, 5, 10];
  static const sizes = [32, 56, 512, 1472];

  String get countLabel => count == 0 ? '∞' : '$count';
  String get intervalLabel => (intervalMs / 1000).toStringAsFixed(intervalMs < 1000 ? 1 : 1);

  PingParams copyWith({int? count, int? intervalMs, int? timeoutSec, int? packetSize, IpVersionPref? ipVersion}) =>
      PingParams(
        count: count ?? this.count,
        intervalMs: intervalMs ?? this.intervalMs,
        timeoutSec: timeoutSec ?? this.timeoutSec,
        packetSize: packetSize ?? this.packetSize,
        ipVersion: ipVersion ?? this.ipVersion,
      );

  Map<String, Object?> toJson() => {
    'count': count,
    'intervalMs': intervalMs,
    'timeoutSec': timeoutSec,
    'packetSize': packetSize,
    'ipVersion': ipVersion.name,
  };

  factory PingParams.fromJson(Map<String, dynamic> j) => PingParams(
    count: j['count'] as int? ?? 0,
    intervalMs: j['intervalMs'] as int? ?? 1000,
    timeoutSec: j['timeoutSec'] as int? ?? 5,
    packetSize: j['packetSize'] as int? ?? 56,
    ipVersion: IpVersionPref.values.firstWhere((v) => v.name == j['ipVersion'], orElse: () => IpVersionPref.auto),
  );
}

enum ReplyState { ok, slow, timeout, unreachable }

@immutable
class PingReply {
  const PingReply({
    required this.seq,
    required this.at,
    required this.state,
    this.rttMs,
    this.ttl,
    this.from,
    this.v6 = false,
  });

  final int seq;
  final DateTime at;
  final ReplyState state;
  final double? rttMs;
  final int? ttl;
  final String? from;
  final bool v6;

  bool get received => state == ReplyState.ok || state == ReplyState.slow;

  Map<String, Object?> toJson() => {
    'seq': seq,
    'at': at.millisecondsSinceEpoch,
    'state': state.name,
    'rtt': rttMs,
    'ttl': ttl,
    if (v6) 'v6': true,
  };

  factory PingReply.fromJson(Map<String, dynamic> j) => PingReply(
    seq: j['seq'] as int,
    at: DateTime.fromMillisecondsSinceEpoch(j['at'] as int),
    state: ReplyState.values.firstWhere((s) => s.name == j['state'], orElse: () => ReplyState.timeout),
    rttMs: (j['rtt'] as num?)?.toDouble(),
    ttl: j['ttl'] as int?,
    v6: j['v6'] == true,
  );
}

@immutable
class PingStats {
  const PingStats({this.sent = 0, this.received = 0, this.min, this.avg, this.max, this.jitter});

  factory PingStats.of(Iterable<PingReply> replies) {
    var sent = 0;
    final rtts = <double>[];
    for (final r in replies) {
      sent++;
      if (r.received && r.rttMs != null) rtts.add(r.rttMs!);
    }
    if (rtts.isEmpty) return PingStats(sent: sent);
    var sum = 0.0, lo = double.infinity, hi = 0.0, jitterSum = 0.0;
    for (var i = 0; i < rtts.length; i++) {
      final v = rtts[i];
      sum += v;
      lo = math.min(lo, v);
      hi = math.max(hi, v);
      if (i > 0) jitterSum += (v - rtts[i - 1]).abs();
    }
    return PingStats(
      sent: sent,
      received: rtts.length,
      min: lo,
      avg: sum / rtts.length,
      max: hi,
      jitter: rtts.length > 1 ? jitterSum / (rtts.length - 1) : 0,
    );
  }

  final int sent;
  final int received;
  final double? min;
  final double? avg;
  final double? max;

  /// Mean absolute difference between consecutive replies.
  final double? jitter;

  int get lost => sent - received;
  double get lossPct => sent == 0 ? 0 : lost / sent * 100;

  Map<String, Object?> toJson() => {
    'sent': sent,
    'received': received,
    'min': min,
    'avg': avg,
    'max': max,
    'jitter': jitter,
  };

  factory PingStats.fromJson(Map<String, dynamic> j) => PingStats(
    sent: j['sent'] as int? ?? 0,
    received: j['received'] as int? ?? 0,
    min: (j['min'] as num?)?.toDouble(),
    avg: (j['avg'] as num?)?.toDouble(),
    max: (j['max'] as num?)?.toDouble(),
    jitter: (j['jitter'] as num?)?.toDouble(),
  );
}

/// Down-samples values into [buckets] averages (for sparklines).
List<double> bucketAverages(List<double> values, int buckets) {
  if (values.isEmpty) return const [];
  if (values.length <= buckets) return List.of(values);
  final out = <double>[];
  for (var b = 0; b < buckets; b++) {
    final start = (b * values.length / buckets).floor();
    final end = ((b + 1) * values.length / buckets).floor();
    final slice = values.sublist(start, math.max(end, start + 1));
    out.add(slice.reduce((a, c) => a + c) / slice.length);
  }
  return out;
}
