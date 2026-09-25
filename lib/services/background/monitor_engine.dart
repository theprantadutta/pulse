import 'dart:async';
import 'dart:math' as math;

import 'package:drift/drift.dart';

import '../../data/db/app_database.dart';
import '../../data/models/app_settings.dart';
import '../net/lan/lan_scanner.dart';
import '../net/network_details.dart';
import '../net/ping_prober.dart';
import 'notifications.dart';

/// Notification channels of an alert rule (bitmask).
class AlertChannel {
  AlertChannel._();
  static const push = 1;
  static const tray = 2;
  static const sound = 4;
}

/// Alert rule metrics.
class AlertMetric {
  AlertMetric._();
  static const latency = 'latency';
  static const loss = 'loss';
  static const down = 'down';
  static const newDevice = 'newDevice';
}

/// What one monitoring cycle found, for the tray tooltip and the
/// foreground-service notification.
class CycleReport {
  const CycleReport({
    required this.targets,
    required this.down,
    required this.firing,
    required this.at,
    this.fired = const [],
  });

  final int targets;
  final int down;
  final int firing;
  final DateTime at;

  /// Messages of rules that fired during this cycle.
  final List<String> fired;

  String get summary {
    if (targets == 0) return 'No targets';
    final parts = <String>['$targets target${targets == 1 ? '' : 's'}'];
    if (down > 0) parts.add('$down down');
    if (firing > 0) parts.add('$firing alert${firing == 1 ? '' : 's'}');
    if (down == 0 && firing == 0) parts.add('all healthy');
    return parts.join(' · ');
  }
}

/// Runs background checks, maintains incidents and fires alert rules.
class MonitorEngine {
  MonitorEngine({required this.db, required this.prober, required this.settings, this.onTrayAlert, this.mutedUntil});

  final AppDatabase db;
  final PingProber prober;
  final AppSettings Function() settings;

  /// Desktop tray / Android service notification hook for the TRAY channel.
  final void Function(String message)? onTrayAlert;

  /// Alerts are logged but not delivered while muted.
  final DateTime? Function()? mutedUntil;

  DateTime? _lastPrune;
  bool _busy = false;

  static const _probesPerCheck = 3;

  Future<CycleReport> runCycle() async {
    if (_busy) return CycleReport(targets: 0, down: 0, firing: 0, at: DateTime.now());
    _busy = true;
    try {
      final now = DateTime.now();
      final targets = await (db.select(db.monitorTargets)..where((t) => t.enabled.equals(true))).get();
      final results = <int, MonitorCheck>{};
      await _pool(targets, 8, (t) async {
        final c = await _check(t, now);
        results[t.id] = c;
      });
      for (final t in targets) {
        await _updateIncidents(t, now);
      }
      final fired = await _evaluateRules(targets, now);
      await _pruneIfDue(now);
      final firing = await (db.select(
        db.alertRules,
      )..where((r) => r.firing.equals(true) & r.enabled.equals(true))).get();
      return CycleReport(
        targets: targets.length,
        down: results.values.where((c) => c.received == 0).length,
        firing: firing.length,
        at: now,
        fired: fired,
      );
    } finally {
      _busy = false;
    }
  }

  Future<void> _pool<T>(List<T> items, int size, Future<void> Function(T) run) async {
    var i = 0;
    Future<void> worker() async {
      while (i < items.length) {
        final item = items[i++];
        await run(item);
      }
    }

    await Future.wait([for (var w = 0; w < math.min(size, items.length); w++) worker()]);
  }

  Future<MonitorCheck> _check(MonitorTarget t, DateTime at) async {
    final rtts = <double>[];
    for (var i = 0; i < _probesPerCheck; i++) {
      final r = await prober.probe(t.host, timeout: const Duration(seconds: 2), packetSize: 32);
      if (r.ok && r.rttMs != null) rtts.add(r.rttMs!);
      if (i < _probesPerCheck - 1) await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    final check = MonitorChecksCompanion.insert(
      targetId: t.id,
      at: at,
      sent: _probesPerCheck,
      received: rtts.length,
      rttAvg: Value(rtts.isEmpty ? null : rtts.reduce((a, b) => a + b) / rtts.length),
      rttMax: Value(rtts.isEmpty ? null : rtts.reduce(math.max)),
    );
    final id = await db.into(db.monitorChecks).insert(check);
    return (await (db.select(db.monitorChecks)..where((c) => c.id.equals(id))).getSingle());
  }

  Future<List<MonitorCheck>> _recentChecks(int targetId, {int limit = 10, DateTime? since}) {
    final q = db.select(db.monitorChecks)
      ..where((c) => c.targetId.equals(targetId))
      ..orderBy([(c) => OrderingTerm.desc(c.at)])
      ..limit(limit);
    if (since != null) q.where((c) => c.at.isBiggerOrEqualValue(since));
    return q.get();
  }

  /// Median RTT over the last 24 hours — the target's normal.
  Future<double?> _baseline(int targetId, DateTime now) async {
    final rows =
        await (db.select(db.monitorChecks)
              ..where(
                (c) =>
                    c.targetId.equals(targetId) &
                    c.at.isBiggerOrEqualValue(now.subtract(const Duration(hours: 24))) &
                    c.rttAvg.isNotNull(),
              )
              ..orderBy([(c) => OrderingTerm.desc(c.at)])
              ..limit(1440))
            .get();
    if (rows.length < 5) return null;
    final v = rows.map((r) => r.rttAvg!).toList()..sort();
    return v[v.length ~/ 2];
  }

  Future<Incident?> _open(int targetId, String kind) =>
      (db.select(db.incidents)
            ..where((i) => i.targetId.equals(targetId) & i.kind.equals(kind) & i.endedAt.isNull())
            ..limit(1))
          .getSingleOrNull();

  Future<void> _updateIncidents(MonitorTarget t, DateTime now) async {
    final recent = await _recentChecks(t.id, limit: 5);
    if (recent.isEmpty) return;
    final last = recent.first;
    final name = t.name.isEmpty ? t.host : t.name;

    // DOWN: the latest check got nothing back.
    final down = await _open(t.id, 'down');
    if (last.received == 0) {
      if (down == null) {
        // A full outage supersedes loss / latency incidents.
        for (final kind in const ['loss', 'latency']) {
          final other = await _open(t.id, kind);
          if (other != null) await _close(other, now);
        }
        await db
            .into(db.incidents)
            .insert(
              IncidentsCompanion.insert(
                targetId: t.id,
                kind: 'down',
                title: '$name unreachable',
                description: 'No reply to ${last.sent} probes',
                startedAt: last.at,
                failedChecks: const Value(1),
              ),
            );
      } else {
        final failed = down.failedChecks + 1;
        await (db.update(db.incidents)..where((i) => i.id.equals(down.id))).write(
          IncidentsCompanion(
            failedChecks: Value(failed),
            description: Value('Timeout on ${failed * last.sent} probes'),
          ),
        );
      }
    } else if (down != null) {
      await _close(down, now);
    }

    // LOSS: 10%+ partial loss over the recent checks where the host still
    // answered. Fully-down checks belong to the DOWN incident instead.
    final answering = recent.where((c) => c.received > 0).toList();
    final sent = answering.fold<int>(0, (a, c) => a + c.sent);
    final lost = answering.fold<int>(0, (a, c) => a + (c.sent - c.received));
    final lossPct = sent == 0 ? 0.0 : lost / sent * 100;
    final lossOpen = await _open(t.id, 'loss');
    if (last.received == 0) return;
    if (answering.length >= 3 && lossPct >= 10) {
      if (lossOpen == null) {
        await db
            .into(db.incidents)
            .insert(
              IncidentsCompanion.insert(
                targetId: t.id,
                kind: 'loss',
                title: '$name packet loss',
                description: '${lossPct.round()}% loss',
                startedAt: answering.last.at,
                peak: Value(lossPct),
              ),
            );
      } else {
        final peak = math.max(lossOpen.peak ?? 0, lossPct);
        final mins = now.difference(lossOpen.startedAt).inMinutes;
        await (db.update(db.incidents)..where((i) => i.id.equals(lossOpen.id))).write(
          IncidentsCompanion(
            peak: Value(peak),
            description: Value('${lossPct.round()}% loss for $mins min, peak ${peak.round()}%'),
          ),
        );
      }
    } else if (lossOpen != null && lossPct < 2) {
      await _close(lossOpen, now);
    }

    // LATENCY: last three checks well above this target's normal.
    final base = await _baseline(t.id, now);
    final last3 = recent.take(3).where((c) => c.rttAvg != null).toList();
    final latOpen = await _open(t.id, 'latency');
    if (base != null && last3.length == 3) {
      final avg = last3.map((c) => c.rttAvg!).reduce((a, b) => a + b) / 3;
      final limit = math.max(base * 3, base + 80);
      if (avg > limit) {
        if (latOpen == null) {
          await db
              .into(db.incidents)
              .insert(
                IncidentsCompanion.insert(
                  targetId: t.id,
                  kind: 'latency',
                  title: '$name latency high',
                  description: 'Avg ${avg.round()} ms (normal ${base.round()} ms)',
                  startedAt: last3.last.at,
                  peak: Value(avg),
                ),
              );
        } else {
          final peak = math.max(latOpen.peak ?? 0, avg);
          await (db.update(db.incidents)..where((i) => i.id.equals(latOpen.id))).write(
            IncidentsCompanion(peak: Value(peak), description: Value('Avg ${avg.round()} ms, peak ${peak.round()} ms')),
          );
        }
      } else if (latOpen != null && avg < base * 1.5 + 20) {
        await _close(latOpen, now);
      }
    }
  }

  Future<void> _close(Incident i, DateTime now) =>
      (db.update(db.incidents)..where((x) => x.id.equals(i.id))).write(IncidentsCompanion(endedAt: Value(now)));

  /// Returns messages of rules that fired this cycle.
  Future<List<String>> _evaluateRules(List<MonitorTarget> targets, DateTime now) async {
    final rules = await (db.select(
      db.alertRules,
    )..where((r) => r.enabled.equals(true) & r.metric.isNotIn([AlertMetric.newDevice]))).get();
    final fired = <String>[];
    for (final rule in rules) {
      final watched = rule.target == '*'
          ? targets
          : targets.where((t) => t.host.toLowerCase() == rule.target.toLowerCase()).toList();
      String? breach;
      double? value;
      for (final t in watched) {
        final window = now.subtract(Duration(seconds: math.max(rule.forSeconds, settings().monitorIntervalSec * 2)));
        final checks = await _recentChecks(t.id, limit: 60, since: window);
        if (checks.isEmpty) continue;
        final last = checks.first;
        switch (rule.metric) {
          case AlertMetric.latency:
            if (last.rttAvg != null && last.rttAvg! > rule.threshold) {
              value = last.rttAvg;
              breach = '${t.host} RTT ${last.rttAvg!.round()} ms (> ${rule.threshold.round()})';
            }
          case AlertMetric.loss:
            final sent = checks.fold<int>(0, (a, c) => a + c.sent);
            final lost = checks.fold<int>(0, (a, c) => a + (c.sent - c.received));
            final pct = sent == 0 ? 0.0 : lost / sent * 100;
            if (pct > rule.threshold) {
              value = pct;
              breach = '${t.host} loss ${pct.round()}% (> ${rule.threshold.round()}%)';
            }
          case AlertMetric.down:
            if (last.received == 0) {
              value = 0;
              breach = '${t.host} unreachable';
            }
        }
        if (breach != null) break;
      }

      if (breach == null) {
        if (rule.breachSince != null || rule.firing) {
          await (db.update(db.alertRules)..where((r) => r.id.equals(rule.id))).write(
            const AlertRulesCompanion(breachSince: Value(null), firing: Value(false)),
          );
        }
        continue;
      }
      final since = rule.breachSince ?? now;
      if (rule.breachSince == null) {
        await (db.update(
          db.alertRules,
        )..where((r) => r.id.equals(rule.id))).write(AlertRulesCompanion(breachSince: Value(now)));
      }
      final held = now.difference(since).inSeconds >= rule.forSeconds - 1;
      if (held && !rule.firing) {
        final message = rule.metric == AlertMetric.down ? '$breach for ${_dur(now.difference(since))}' : breach;
        await db
            .into(db.alertEvents)
            .insert(AlertEventsCompanion.insert(ruleId: rule.id, at: now, message: message, value: Value(value)));
        await (db.update(db.alertRules)..where((r) => r.id.equals(rule.id))).write(
          AlertRulesCompanion(firing: const Value(true), lastFiredAt: Value(now)),
        );
        fired.add(message);
        await deliver(rule, message);
      }
    }
    return fired;
  }

  static String _dur(Duration d) => d.inSeconds < 60 ? '${d.inSeconds} s' : '${d.inMinutes} min';

  /// Sends an alert through the rule's channels (also used for new-device
  /// rules fired by the LAN watch).
  Future<void> deliver(AlertRule rule, String message) async {
    final muted = mutedUntil?.call();
    if (muted != null && DateTime.now().isBefore(muted)) return;
    final s = settings();
    if ((rule.channels & AlertChannel.tray) != 0) onTrayAlert?.call(message);
    if ((rule.channels & AlertChannel.push) != 0 && s.notificationsEnabled) {
      await PulseNotifications.show(
        id: rule.id,
        title: rule.title,
        body: message,
        sound: (rule.channels & AlertChannel.sound) != 0 && s.notificationSound,
      );
    }
  }

  DateTime? _lastLanWatch;

  /// Sweeps the LAN (at most every 15 minutes) and fires "new device" rules
  /// for hosts never seen on this subnet. Returns the new devices.
  Future<List<LanHost>> runLanWatch({bool force = false}) async {
    final now = DateTime.now();
    final rules = await (db.select(
      db.alertRules,
    )..where((r) => r.enabled.equals(true) & r.metric.equals(AlertMetric.newDevice))).get();
    if (rules.isEmpty && !settings().lanDeviceWatch) return const [];
    if (!force && _lastLanWatch != null && now.difference(_lastLanWatch!).inMinutes < 15) return const [];
    _lastLanWatch = now;

    final link = await const NetworkDetailsReader().read();
    if (link.localIpv4 == null) return const [];
    final prefix = link.prefixLength ?? 24;
    final cidr = LanScanner.cidrFor(link.localIpv4!, prefix);
    final known = {for (final d in await (db.select(db.lanDevices)..where((t) => t.subnet.equals(cidr))).get()) d.key};
    LanScanProgress? last;
    await for (final p in LanScanner(
      prober: prober,
      concurrency: 32,
    ).scan(localIp: link.localIpv4!, prefix: prefix, gateway: link.gateway)) {
      last = p;
    }
    final hosts = last?.hosts ?? const <LanHost>[];
    final fresh = <LanHost>[];
    await db.batch((b) {
      for (final h in hosts) {
        final key = h.mac ?? h.ip;
        if (!known.contains(key) && !h.isSelf) fresh.add(h);
        b.insert(
          db.lanDevices,
          LanDevicesCompanion.insert(
            key: key,
            ip: h.ip,
            mac: Value(h.mac),
            hostname: Value(h.hostname),
            vendor: Value(h.vendor),
            subnet: cidr,
            firstSeen: now,
            lastSeen: now,
          ),
          onConflict: DoUpdate(
            (old) => LanDevicesCompanion(ip: Value(h.ip), hostname: Value(h.hostname), lastSeen: Value(now)),
          ),
        );
      }
    });
    // The very first sweep of a subnet only learns what is already there.
    if (known.isEmpty) return const [];
    for (final h in fresh) {
      final label = [h.hostname ?? 'Unknown device', h.ip, ?h.mac, ?h.vendor].join(' · ');
      for (final rule in rules) {
        final message = 'New on $cidr: $label';
        await db.into(db.alertEvents).insert(AlertEventsCompanion.insert(ruleId: rule.id, at: now, message: message));
        await (db.update(
          db.alertRules,
        )..where((r) => r.id.equals(rule.id))).write(AlertRulesCompanion(lastFiredAt: Value(now)));
        await deliver(rule, message);
      }
    }
    return fresh;
  }

  Future<void> _pruneIfDue(DateTime now) async {
    if (_lastPrune != null && now.difference(_lastPrune!).inHours < 1) return;
    _lastPrune = now;
    await db.applyRetention(settings().retentionDays);
  }
}
