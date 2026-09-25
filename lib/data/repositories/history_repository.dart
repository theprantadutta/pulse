import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:intl/intl.dart';

import '../db/app_database.dart';
import '../models/app_settings.dart';
import '../models/session_tool.dart';

/// Reads and writes History sessions.
class HistoryRepository {
  HistoryRepository(this.db);
  final AppDatabase db;

  Future<int> save({
    required SessionTool tool,
    required String target,
    String? label,
    required DateTime startedAt,
    required DateTime endedAt,
    double? avgMs,
    double? lossPct,
    String summary = '',
    List<double> trend = const [],
    Map<String, Object?> payload = const {},
  }) {
    return db.into(db.sessions).insert(
      SessionsCompanion.insert(
        tool: tool.name,
        target: target,
        label: Value(label == null || label.trim().isEmpty ? null : label.trim()),
        startedAt: startedAt,
        endedAt: endedAt,
        avgMs: Value(avgMs),
        lossPct: Value(lossPct),
        summary: Value(summary),
        trend: Value(jsonEncode(trend)),
        payload: Value(jsonEncode(payload)),
      ),
    );
  }

  /// Newest first. [search] matches the name, host, tool or summary.
  Stream<List<Session>> watch({SessionTool? tool, String search = ''}) {
    final q = db.select(db.sessions)
      ..orderBy([(s) => OrderingTerm.desc(s.startedAt)]);
    if (tool != null) q.where((s) => s.tool.equals(tool.name));
    final term = search.trim().toLowerCase();
    if (term.isNotEmpty) {
      final like = '%$term%';
      q.where(
        (s) =>
            s.target.lower().like(like) |
            s.label.lower().like(like) |
            s.summary.lower().like(like) |
            s.tool.lower().like(like),
      );
    }
    return q.watch();
  }

  Future<Session?> byId(int id) =>
      (db.select(db.sessions)..where((s) => s.id.equals(id))).getSingleOrNull();

  Future<void> delete(int id) =>
      (db.delete(db.sessions)..where((s) => s.id.equals(id))).go();

  static List<double> trendOf(Session s) {
    try {
      return [for (final v in jsonDecode(s.trend) as List) (v as num).toDouble()];
    } on Object {
      return const [];
    }
  }

  static Map<String, dynamic> payloadOf(Session s) {
    try {
      return jsonDecode(s.payload) as Map<String, dynamic>;
    } on Object {
      return const {};
    }
  }

  static final _stamp = DateFormat('yyyy-MM-dd HH:mm:ss');

  /// Sessions as CSV or aligned plain text.
  static String export(List<Session> sessions, ExportFormat format) {
    String fmt(double? v) => v == null ? '' : v.toStringAsFixed(1);
    if (format == ExportFormat.csv) {
      String cell(String v) =>
          v.contains(RegExp('[",\n]')) ? '"${v.replaceAll('"', '""')}"' : v;
      final b = StringBuffer('started,ended,name,target,tool,avg_ms,loss_pct,summary\n');
      for (final s in sessions) {
        b.writeln([
          _stamp.format(s.startedAt),
          _stamp.format(s.endedAt),
          cell(s.label ?? ''),
          cell(s.target),
          s.tool.toUpperCase(),
          fmt(s.avgMs),
          fmt(s.lossPct),
          cell(s.summary),
        ].join(','));
      }
      return b.toString();
    }
    final b = StringBuffer();
    for (final s in sessions) {
      b.writeln(
        '${_stamp.format(s.startedAt)}  ${s.tool.toUpperCase().padRight(5)}  '
        '${(s.label ?? '-').padRight(18)}  ${s.target.padRight(28)}  '
        'avg ${fmt(s.avgMs).padLeft(7)} ms  loss ${fmt(s.lossPct).padLeft(5)}%  ${s.summary}',
      );
    }
    return b.toString();
  }

  /// Full text report of one session (History → .TXT).
  static String report(Session s) {
    final p = payloadOf(s);
    final b = StringBuffer()
      ..writeln('PULSE ${s.tool.toUpperCase()} SESSION')
      ..writeln('Name:    ${s.label ?? '-'}')
      ..writeln('Target:  ${s.target}')
      ..writeln('Started: ${_stamp.format(s.startedAt)}')
      ..writeln('Ended:   ${_stamp.format(s.endedAt)}')
      ..writeln('Result:  ${s.summary}');
    final stats = p['stats'];
    if (stats is Map) {
      b.writeln();
      stats.forEach((k, v) => b.writeln('${'$k'.padRight(9)}${v is num ? v.toStringAsFixed(2) : v}'));
    }
    final replies = p['replies'];
    if (replies is List && replies.isNotEmpty) {
      b
        ..writeln()
        ..writeln('SEQ   TIME                     RTT       TTL  STATE');
      for (final r in replies.cast<Map>()) {
        final at = DateTime.fromMillisecondsSinceEpoch(r['at'] as int);
        final rtt = r['rtt'] == null ? '—' : '${(r['rtt'] as num).toStringAsFixed(1)} ms';
        b.writeln(
          '${'${r['seq']}'.padLeft(3, '0')}   ${DateFormat('yyyy-MM-dd HH:mm:ss.SSS').format(at)}  '
          '${rtt.padRight(9)} ${'${r['ttl'] ?? '—'}'.padRight(4)} ${'${r['state']}'.toUpperCase()}',
        );
      }
    }
    return b.toString();
  }
}
