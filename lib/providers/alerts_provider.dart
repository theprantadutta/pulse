import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../core/constants/shared_preference_keys.dart';
import '../data/db/app_database.dart';
import '../services/background/monitor_engine.dart';
import 'database_provider.dart';
import 'monitor_provider.dart';
import 'settings_provider.dart';

final alertRulesProvider = StreamProvider<List<AlertRule>>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.alertRules)..orderBy([(r) => OrderingTerm.asc(r.createdAt)])).watch();
});

@immutable
class FiredAlert {
  const FiredAlert(this.event, this.rule);
  final AlertEvent event;
  final AlertRule rule;
}

final alertEventsProvider = StreamProvider<List<FiredAlert>>((ref) {
  final db = ref.watch(databaseProvider);
  final q = db.select(db.alertEvents).join([
    innerJoin(db.alertRules, db.alertRules.id.equalsExp(db.alertEvents.ruleId)),
  ])
    ..orderBy([OrderingTerm.desc(db.alertEvents.at)])
    ..limit(30);
  return q.watch().map((rows) => [for (final r in rows) FiredAlert(r.readTable(db.alertEvents), r.readTable(db.alertRules))]);
});

/// The newest undismissed event of a rule that is still firing (banner).
final activeAlertProvider = Provider<FiredAlert?>((ref) {
  final events = ref.watch(alertEventsProvider).value ?? const [];
  for (final e in events) {
    if (!e.event.dismissed && e.rule.firing) return e;
  }
  return null;
});

final alertsMutedUntilProvider = NotifierProvider<MuteNotifier, DateTime?>(MuteNotifier.new);

class MuteNotifier extends Notifier<DateTime?> {
  @override
  DateTime? build() {
    final ms = ref.read(sharedPreferencesProvider).getInt(kAlertsMutedUntilKey);
    final until = ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
    return until != null && until.isAfter(DateTime.now()) ? until : null;
  }

  Future<void> muteFor(Duration d) async {
    final until = DateTime.now().add(d);
    await ref.read(sharedPreferencesProvider).setInt(kAlertsMutedUntilKey, until.millisecondsSinceEpoch);
    state = until;
  }

  Future<void> unmute() async {
    await ref.read(sharedPreferencesProvider).remove(kAlertsMutedUntilKey);
    state = null;
  }
}

/// Editable copy of a rule for the editor.
@immutable
class RuleDraft {
  const RuleDraft({
    this.id,
    this.title = 'High latency',
    this.target = '',
    this.metric = AlertMetric.latency,
    this.threshold = 100,
    this.forSeconds = 30,
    this.channels = AlertChannel.push | AlertChannel.tray,
    this.enabled = true,
  });

  factory RuleDraft.of(AlertRule r) => RuleDraft(
    id: r.id,
    title: r.title,
    target: r.target,
    metric: r.metric,
    threshold: r.threshold,
    forSeconds: r.forSeconds,
    channels: r.channels,
    enabled: r.enabled,
  );

  final int? id;
  final String title;
  final String target;
  final String metric;
  final double threshold;
  final int forSeconds;
  final int channels;
  final bool enabled;

  RuleDraft copyWith({String? title, String? target, String? metric, double? threshold, int? forSeconds, int? channels}) =>
      RuleDraft(
        id: id,
        title: title ?? this.title,
        target: target ?? this.target,
        metric: metric ?? this.metric,
        threshold: threshold ?? this.threshold,
        forSeconds: forSeconds ?? this.forSeconds,
        channels: channels ?? this.channels,
        enabled: enabled,
      );

  /// Slider range and unit for the metric.
  (double max, String unit) get scale => switch (metric) {
    AlertMetric.latency => (200, 'MS'),
    AlertMetric.loss => (50, '%'),
    _ => (0, ''),
  };

  static String defaultTitle(String metric) => switch (metric) {
    AlertMetric.latency => 'High latency',
    AlertMetric.loss => 'Packet loss',
    AlertMetric.down => 'Target down',
    AlertMetric.newDevice => 'New LAN device',
    _ => 'Alert',
  };
}

/// Plain-language condition, e.g. "8.8.8.8 · RTT > 100 ms for 30 s".
String ruleCondition(AlertRule r) {
  final who = r.target == '*' ? 'Any target' : r.target;
  final dur = r.forSeconds >= 60 ? '${r.forSeconds ~/ 60} min' : '${r.forSeconds} s';
  return switch (r.metric) {
    AlertMetric.latency => '$who · RTT > ${r.threshold.round()} ms for $dur',
    AlertMetric.loss => '$who · loss > ${r.threshold.round()}% for $dur',
    AlertMetric.down => '$who · unreachable for $dur',
    AlertMetric.newDevice => 'Unknown device joins the local network',
    _ => r.metric,
  };
}

String channelLabel(int channels) => [
  if (channels & AlertChannel.push != 0) 'PUSH',
  if (channels & AlertChannel.tray != 0) 'TRAY',
  if (channels & AlertChannel.sound != 0) 'SOUND',
].join(' + ');

class AlertRulesRepository {
  AlertRulesRepository(this.db, this.targets);
  final AppDatabase db;
  final MonitorTargetsRepository targets;

  Future<int> save(RuleDraft d) async {
    // Rules evaluate monitor checks, so a watched host must be monitored.
    if (d.metric != AlertMetric.newDevice && d.target != '*' && d.target.isNotEmpty) {
      await targets.add(d.target, '');
    }
    final companion = AlertRulesCompanion(
      title: Value(d.title.trim().isEmpty ? RuleDraft.defaultTitle(d.metric) : d.title.trim()),
      target: Value(d.metric == AlertMetric.newDevice ? '*' : d.target.trim()),
      metric: Value(d.metric),
      threshold: Value(d.threshold),
      forSeconds: Value(d.forSeconds),
      channels: Value(d.channels),
      enabled: Value(d.enabled),
    );
    if (d.id == null) {
      return db.into(db.alertRules).insert(companion.copyWith(createdAt: Value(DateTime.now())));
    }
    await (db.update(db.alertRules)..where((r) => r.id.equals(d.id!))).write(
      companion.copyWith(breachSince: const Value(null), firing: const Value(false)),
    );
    return d.id!;
  }

  Future<void> setEnabled(int id, bool on) => (db.update(db.alertRules)..where((r) => r.id.equals(id))).write(
    AlertRulesCompanion(enabled: Value(on), firing: const Value(false), breachSince: const Value(null)),
  );

  Future<void> delete(int id) => (db.delete(db.alertRules)..where((r) => r.id.equals(id))).go();

  Future<void> dismiss(int eventId) => (db.update(db.alertEvents)..where((e) => e.id.equals(eventId)))
      .write(const AlertEventsCompanion(dismissed: Value(true)));
}

final alertRulesRepositoryProvider = Provider<AlertRulesRepository>(
  (ref) => AlertRulesRepository(ref.watch(databaseProvider), ref.watch(monitorTargetsRepositoryProvider)),
);
