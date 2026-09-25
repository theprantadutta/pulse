import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/db/app_database.dart';
import '../data/models/session_tool.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase.open();
  ref.onDispose(db.close);
  return db;
});

/// The most recent session of every tool, for the Tools hub subtitles.
final latestSessionsProvider = StreamProvider<Map<SessionTool, Session>>((ref) {
  final db = ref.watch(databaseProvider);
  final latest = db.sessions.id.max();
  final query = db.selectOnly(db.sessions)
    ..addColumns([db.sessions.tool, latest])
    ..groupBy([db.sessions.tool]);
  return query.watch().asyncMap((rows) async {
    final ids = [for (final r in rows) r.read(latest)].whereType<int>().toList();
    if (ids.isEmpty) return <SessionTool, Session>{};
    final sessions = await (db.select(db.sessions)..where((s) => s.id.isIn(ids))).get();
    return {
      for (final s in sessions)
        if (SessionTool.byName(s.tool) != null) SessionTool.byName(s.tool)!: s,
    };
  });
});
