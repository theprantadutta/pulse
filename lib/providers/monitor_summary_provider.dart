import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'database_provider.dart';
import 'settings_provider.dart';

class MonitorSummary {
  const MonitorSummary({required this.targets, required this.live});
  final int targets;
  final bool live;
}

/// Enabled monitor targets and whether monitoring is switched on.
final monitorSummaryProvider = StreamProvider<MonitorSummary>((ref) {
  final db = ref.watch(databaseProvider);
  final enabled = ref.watch(settingsProvider.select((s) => s.monitorInBackground));
  final count = db.monitorTargets.id.count();
  final q = db.selectOnly(db.monitorTargets)
    ..addColumns([count])
    ..where(db.monitorTargets.enabled.equals(true));
  return q.watchSingle().map(
    (row) => MonitorSummary(targets: row.read(count) ?? 0, live: enabled),
  );
});
