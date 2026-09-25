import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'database_provider.dart';
import 'monitor_provider.dart';

class MonitorSummary {
  const MonitorSummary({required this.targets, required this.live});
  final int targets;
  final bool live;
}

/// Enabled monitor targets and whether monitoring is actually running.
final monitorSummaryProvider = StreamProvider<MonitorSummary>((ref) {
  final db = ref.watch(databaseProvider);
  final live = ref.watch(monitorRunnerProvider.select((s) => s.live));
  final count = db.monitorTargets.id.count();
  final q = db.selectOnly(db.monitorTargets)
    ..addColumns([count])
    ..where(db.monitorTargets.enabled.equals(true));
  return q.watchSingle().map((row) => MonitorSummary(targets: row.read(count) ?? 0, live: live));
});
