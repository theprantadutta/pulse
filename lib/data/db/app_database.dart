import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

/// Every finished tool run (ping, traceroute, speed test, …) lands here and
/// is listed on the History screen.
class Sessions extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// One of [SessionTool] names.
  TextColumn get tool => text()();
  TextColumn get target => text()();

  /// User-given name, e.g. "Office PC" (schema v2).
  TextColumn get label => text().nullable()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endedAt => dateTime()();
  RealColumn get avgMs => real().nullable()();
  RealColumn get lossPct => real().nullable()();

  /// Short one-line result for lists, e.g. "24 MS · 0%".
  TextColumn get summary => text().withDefault(const Constant(''))();

  /// JSON array of up to 12 numbers for the sparkline.
  TextColumn get trend => text().withDefault(const Constant('[]'))();

  /// Tool-specific JSON with the complete result.
  TextColumn get payload => text().withDefault(const Constant('{}'))();
}

/// Named ping targets ("Personal PC" → 192.168.1.20) that can be started
/// together as a multi-ping (schema v2).
class SavedTargets extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get host => text()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get lastUsedAt => dateTime().nullable()();
}

class MonitorTargets extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get host => text()();
  TextColumn get name => text()();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
}

/// One background check of a target: a short burst of probes.
class MonitorChecks extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get targetId =>
      integer().references(MonitorTargets, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get at => dateTime()();
  IntColumn get sent => integer()();
  IntColumn get received => integer()();
  RealColumn get rttAvg => real().nullable()();
  RealColumn get rttMax => real().nullable()();

  @override
  List<Set<Column>> get uniqueKeys => [];
}

class Incidents extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get targetId =>
      integer().references(MonitorTargets, #id, onDelete: KeyAction.cascade)();

  /// down | loss | latency
  TextColumn get kind => text()();
  TextColumn get title => text()();
  TextColumn get description => text()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endedAt => dateTime().nullable()();
  RealColumn get peak => real().nullable()();
  IntColumn get failedChecks => integer().withDefault(const Constant(0))();
}

class AlertRules extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();

  /// A host, or '*' for any monitored target.
  TextColumn get target => text()();

  /// latency | loss | down | newDevice
  TextColumn get metric => text()();
  RealColumn get threshold => real().withDefault(const Constant(0))();
  IntColumn get forSeconds => integer().withDefault(const Constant(30))();

  /// Bitmask of [AlertChannel] values.
  IntColumn get channels => integer().withDefault(const Constant(1))();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();

  /// When the condition first became true in the current breach, if any.
  DateTimeColumn get breachSince => dateTime().nullable()();

  /// Set while the rule is firing; cleared when the condition recovers.
  BoolColumn get firing => boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastFiredAt => dateTime().nullable()();
}

class AlertEvents extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get ruleId =>
      integer().references(AlertRules, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get at => dateTime()();
  TextColumn get message => text()();
  RealColumn get value => real().nullable()();
  BoolColumn get dismissed => boolean().withDefault(const Constant(false))();
}

/// Every device seen by a LAN scan, keyed by MAC (or IP when the MAC is not
/// readable on this platform).
class LanDevices extends Table {
  TextColumn get key => text()();
  TextColumn get ip => text()();
  TextColumn get mac => text().nullable()();
  TextColumn get hostname => text().nullable()();
  TextColumn get vendor => text().nullable()();
  TextColumn get subnet => text()();
  DateTimeColumn get firstSeen => dateTime()();
  DateTimeColumn get lastSeen => dateTime()();

  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(
  tables: [
    Sessions,
    SavedTargets,
    MonitorTargets,
    MonitorChecks,
    Incidents,
    AlertRules,
    AlertEvents,
    LanDevices,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// Opens the on-disk database. [shareAcrossIsolates] lets the UI isolate,
  /// the Android foreground service and WorkManager share one connection.
  AppDatabase.open()
    : super(
        driftDatabase(
          name: 'pulse',
          native: const DriftNativeOptions(shareAcrossIsolates: true),
        ),
      );

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await customStatement(
        'CREATE INDEX checks_target_at ON monitor_checks (target_id, at)',
      );
      await customStatement(
        'CREATE INDEX sessions_started ON sessions (started_at)',
      );
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(sessions, sessions.label);
        await m.createTable(savedTargets);
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  /// Removes sessions, checks and closed incidents older than [days].
  Future<void> applyRetention(int days) async {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    await transaction(() async {
      await (delete(sessions)..where((s) => s.startedAt.isSmallerThanValue(cutoff))).go();
      await (delete(monitorChecks)..where((c) => c.at.isSmallerThanValue(cutoff))).go();
      await (delete(incidents)
            ..where((i) => i.endedAt.isNotNull() & i.endedAt.isSmallerThanValue(cutoff)))
          .go();
      await (delete(alertEvents)..where((e) => e.at.isSmallerThanValue(cutoff))).go();
    });
  }

  /// Deletes history, rules, targets and devices.
  Future<void> clearAll() async {
    await transaction(() async {
      for (final t in allTables) {
        await delete(t).go();
      }
    });
  }
}
