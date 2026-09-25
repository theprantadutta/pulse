import 'dart:async';
import 'dart:math' as math;

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../data/db/app_database.dart';
import '../data/models/app_settings.dart';
import '../data/models/ping_models.dart';
import '../data/models/session_tool.dart';
import '../data/repositories/history_repository.dart';
import '../services/net/dns.dart';
import '../services/net/ping_prober.dart';
import 'database_provider.dart';
import 'settings_provider.dart';

/// Most concurrent live pings allowed at once.
const kMaxLivePings = 32;

/// Replies kept in memory per session for the log and chart.
const _kKeepReplies = 600;

/// Replies stored in the History payload per session.
const _kSaveReplies = 5000;

/// Overridable in tests.
final pingProberProvider = Provider<PingProber>((ref) => const PingProber());

final historyRepositoryProvider = Provider<HistoryRepository>((ref) => HistoryRepository(ref.watch(databaseProvider)));

/// One live (or finished) ping to a host.
@immutable
class PingSession {
  const PingSession({
    required this.id,
    required this.host,
    required this.params,
    required this.startedAt,
    this.name,
    this.running = false,
    this.resolving = false,
    this.replies = const [],
    this.stats = const PingStats(),
    this.describe,
    this.error,
    this.endedAt,
    this.historyId,
  });

  final String id;
  final String host;

  /// User-given label, e.g. "Office PC".
  final String? name;
  final PingParams params;
  final DateTime startedAt;
  final bool running;
  final bool resolving;

  /// Newest last; capped at the most recent replies.
  final List<PingReply> replies;
  final PingStats stats;

  /// Resolved address for names, PTR name for IPs.
  final String? describe;

  /// Set when the target cannot be reached at all (e.g. DNS failure).
  final String? error;
  final DateTime? endedAt;

  /// Row id in History once saved.
  final int? historyId;

  String get title => name?.isNotEmpty == true ? name! : host;
  PingReply? get last => replies.isEmpty ? null : replies.last;

  /// Every probe in the last few failed because the host is unreachable.
  bool get unreachable {
    if (error != null) return true;
    if (replies.length < 3) return false;
    return replies.reversed.take(3).every((r) => r.state == ReplyState.unreachable);
  }

  PingSession copyWith({
    String? name,
    bool? running,
    bool? resolving,
    List<PingReply>? replies,
    PingStats? stats,
    String? describe,
    String? error,
    DateTime? endedAt,
    int? historyId,
    bool clearError = false,
  }) => PingSession(
    id: id,
    host: host,
    params: params,
    startedAt: startedAt,
    name: name ?? this.name,
    running: running ?? this.running,
    resolving: resolving ?? this.resolving,
    replies: replies ?? this.replies,
    stats: stats ?? this.stats,
    describe: describe ?? this.describe,
    error: clearError ? null : error ?? this.error,
    endedAt: endedAt ?? this.endedAt,
    historyId: historyId ?? this.historyId,
  );
}

/// All ping sessions plus which one the live view is showing.
@immutable
class PingBoard {
  const PingBoard({this.sessions = const [], this.focusedId, this.showBoard = false});

  /// Oldest first.
  final List<PingSession> sessions;
  final String? focusedId;

  /// Board grid instead of the single live view.
  final bool showBoard;

  PingSession? get focused {
    for (final s in sessions) {
      if (s.id == focusedId) return s;
    }
    return sessions.isEmpty ? null : sessions.last;
  }

  int get liveCount => sessions.where((s) => s.running).length;

  PingBoard copyWith({List<PingSession>? sessions, String? focusedId, bool? showBoard, bool clearFocus = false}) =>
      PingBoard(
        sessions: sessions ?? this.sessions,
        focusedId: clearFocus ? null : focusedId ?? this.focusedId,
        showBoard: showBoard ?? this.showBoard,
      );
}

/// Running aggregates so stats stay O(1) per reply.
class _Accumulator {
  int sent = 0, received = 0;
  double sum = 0, min = double.infinity, max = 0, jitterSum = 0;
  double? lastRtt;
  int jitterN = 0;

  void add(PingReply r) {
    sent++;
    final v = r.rttMs;
    if (!r.received || v == null) return;
    received++;
    sum += v;
    min = math.min(min, v);
    max = math.max(max, v);
    if (lastRtt != null) {
      jitterSum += (v - lastRtt!).abs();
      jitterN++;
    }
    lastRtt = v;
  }

  PingStats get stats => received == 0
      ? PingStats(sent: sent)
      : PingStats(
          sent: sent,
          received: received,
          min: min,
          avg: sum / received,
          max: max,
          jitter: jitterN == 0 ? 0 : jitterSum / jitterN,
        );
}

class _Runner {
  _Runner(this.session);
  PingSession session;
  Timer? timer;
  int seq = 0;
  int pending = 0;
  bool stopping = false;
  final acc = _Accumulator();
  final all = <PingReply>[];
  final rtts = <double>[];
}

final pingBoardProvider = NotifierProvider<PingBoardNotifier, PingBoard>(PingBoardNotifier.new);

/// The focused session, for widgets that only show one.
final focusedPingProvider = Provider<PingSession?>((ref) => ref.watch(pingBoardProvider.select((b) => b.focused)));

class PingBoardNotifier extends Notifier<PingBoard> {
  final _runners = <String, _Runner>{};
  var _nextId = 0;

  @override
  PingBoard build() {
    ref.onDispose(() {
      for (final r in _runners.values) {
        r.timer?.cancel();
      }
    });
    return const PingBoard();
  }

  void _put(PingSession s) {
    final list = [for (final x in state.sessions) x.id == s.id ? s : x];
    state = state.copyWith(sessions: list);
  }

  /// Starts a new live ping. Returns the session id, or null when the
  /// concurrent limit is reached.
  Future<String?> start(String host, {String? name, PingParams? params}) async {
    host = host.trim();
    if (host.isEmpty) return null;
    if (state.liveCount >= kMaxLivePings) return null;
    final settings = ref.read(settingsProvider);
    final p = params ?? PingParams.fromSettings(settings);
    final saved = await ref.read(savedTargetsRepositoryProvider).touch(host);
    final id = 'p${DateTime.now().microsecondsSinceEpoch}_${_nextId++}';
    final session = PingSession(
      id: id,
      host: host,
      name: (name?.trim().isNotEmpty ?? false) ? name!.trim() : saved?.name,
      params: p,
      startedAt: DateTime.now(),
      running: true,
      resolving: true,
    );
    final runner = _Runner(session);
    _runners[id] = runner;
    state = state.copyWith(sessions: [...state.sessions, session], focusedId: id);

    final family = switch (p.ipVersion) {
      IpVersionPref.ipv4 => ProbeFamily.ipv4,
      IpVersionPref.ipv6 => ProbeFamily.ipv6,
      _ => ProbeFamily.auto,
    };
    try {
      await Dns.resolve(host, family: family);
    } on DnsFailure catch (e) {
      runner.session = runner.session.copyWith(
        running: false,
        resolving: false,
        error: 'DNS lookup failed for ${e.host}${e.reason == null ? '' : ' — ${e.reason}'}',
        endedAt: DateTime.now(),
      );
      _put(runner.session);
      return id;
    }
    if (runner.stopping) return id;
    runner.session = runner.session.copyWith(resolving: false);
    _put(runner.session);
    Dns.describe(host).then((d) {
      if (d == null || !_runners.containsKey(id)) return;
      runner.session = runner.session.copyWith(describe: d);
      _put(runner.session);
    });

    void tick() {
      if (runner.stopping) return;
      if (p.count > 0 && runner.seq >= p.count) {
        runner.timer?.cancel();
        return;
      }
      runner.seq++;
      final seq = runner.seq;
      if (p.ipVersion == IpVersionPref.both) {
        _fire(runner, seq, ProbeFamily.ipv4);
        _fire(runner, seq, ProbeFamily.ipv6);
      } else {
        _fire(runner, seq, family);
      }
    }

    tick();
    runner.timer = Timer.periodic(Duration(milliseconds: p.intervalMs), (_) => tick());
    return id;
  }

  /// Starts every target in [targets] at once (multi-ping).
  Future<int> startMany(Iterable<({String host, String? name})> targets, {PingParams? params}) async {
    var started = 0;
    for (final t in targets) {
      if (state.liveCount >= kMaxLivePings) break;
      final id = await start(t.host, name: t.name, params: params);
      if (id != null) started++;
    }
    if (started > 1) state = state.copyWith(showBoard: true);
    return started;
  }

  void _fire(_Runner runner, int seq, ProbeFamily family) {
    final p = runner.session.params;
    runner.pending++;
    ref
        .read(pingProberProvider)
        .probe(
          runner.session.host,
          timeout: Duration(seconds: p.timeoutSec),
          packetSize: p.packetSize,
          family: family,
        )
        .then((r) => _onResult(runner, seq, family, r));
  }

  void _onResult(_Runner runner, int seq, ProbeFamily family, ProbeResult r) {
    runner.pending--;
    if (!_runners.containsKey(runner.session.id)) return;
    final slowMs = ref.read(settingsProvider).slowThresholdMs;
    final state0 = switch (r.status) {
      ProbeStatus.ok => (r.rttMs ?? 0) > slowMs ? ReplyState.slow : ReplyState.ok,
      ProbeStatus.unreachable || ProbeStatus.unknownHost => ReplyState.unreachable,
      _ => ReplyState.timeout,
    };
    final reply = PingReply(
      seq: seq,
      at: DateTime.now(),
      state: state0,
      rttMs: r.ok ? r.rttMs : null,
      ttl: r.ttl,
      from: r.from,
      v6: family == ProbeFamily.ipv6,
    );
    runner.acc.add(reply);
    if (runner.all.length < _kSaveReplies) runner.all.add(reply);
    if (reply.rttMs != null) runner.rtts.add(reply.rttMs!);

    final kept = [...runner.session.replies, reply]..sort((a, b) => a.seq.compareTo(b.seq));
    if (kept.length > _kKeepReplies) kept.removeRange(0, kept.length - _kKeepReplies);
    runner.session = runner.session.copyWith(replies: kept, stats: runner.acc.stats);

    final p = runner.session.params;
    final perTick = p.ipVersion == IpVersionPref.both ? 2 : 1;
    final finished = p.count > 0 && runner.acc.sent >= p.count * perTick && runner.pending == 0;
    if (finished && !runner.stopping) {
      stop(runner.session.id);
    } else {
      _put(runner.session);
    }
  }

  /// Stops a session and saves it to History.
  Future<void> stop(String id) async {
    final runner = _runners[id];
    if (runner == null || runner.stopping) return;
    runner.stopping = true;
    runner.timer?.cancel();
    runner.session = runner.session.copyWith(running: false, endedAt: DateTime.now());
    _put(runner.session);
    await _save(runner);
  }

  Future<void> stopAll() async {
    await Future.wait([
      for (final s in state.sessions)
        if (s.running) stop(s.id),
    ]);
  }

  /// Stops (if needed) and removes a session from the board.
  Future<void> remove(String id) async {
    await stop(id);
    _runners.remove(id);
    final list = state.sessions.where((s) => s.id != id).toList();
    state = state.copyWith(
      sessions: list,
      focusedId: state.focusedId == id ? (list.isEmpty ? null : list.last.id) : state.focusedId,
      clearFocus: list.isEmpty,
      showBoard: list.length > 1 && state.showBoard,
    );
  }

  /// Removes every stopped session.
  void clearFinished() {
    final keep = state.sessions.where((s) => s.running).toList();
    for (final s in state.sessions) {
      if (!s.running) _runners.remove(s.id);
    }
    state = state.copyWith(
      sessions: keep,
      focusedId: keep.isEmpty ? null : keep.last.id,
      clearFocus: keep.isEmpty,
      showBoard: keep.length > 1 && state.showBoard,
    );
  }

  /// Restarts a finished session with the same host, name and params.
  Future<String?> restart(String id) async {
    final s = state.sessions.firstWhere((x) => x.id == id);
    await remove(id);
    return start(s.host, name: s.name, params: s.params);
  }

  void rename(String id, String name) {
    final runner = _runners[id];
    if (runner == null) return;
    runner.session = runner.session.copyWith(name: name.trim());
    _put(runner.session);
  }

  void focus(String id) => state = state.copyWith(focusedId: id, showBoard: false);

  void showBoard(bool on) => state = state.copyWith(showBoard: on);

  Future<void> _save(_Runner runner) async {
    final s = runner.session;
    final stats = runner.acc.stats;
    if (stats.sent == 0) return;
    final avg = stats.avg;
    final summary = avg == null
        ? 'no replies · ${stats.lossPct.toStringAsFixed(0)}% loss'
        : '${avg.toStringAsFixed(avg < 10 ? 1 : 0)} ms · ${stats.lossPct.toStringAsFixed(stats.lossPct % 1 == 0 ? 0 : 1)}%';
    final id = await ref
        .read(historyRepositoryProvider)
        .save(
          tool: SessionTool.ping,
          target: s.host,
          label: s.name,
          startedAt: s.startedAt,
          endedAt: s.endedAt ?? DateTime.now(),
          avgMs: avg,
          lossPct: stats.lossPct,
          summary: summary,
          trend: bucketAverages(runner.rtts, 12),
          payload: {
            'params': s.params.toJson(),
            'stats': stats.toJson(),
            'replies': [for (final r in runner.all) r.toJson()],
          },
        );
    runner.session = runner.session.copyWith(historyId: id);
    if (_runners.containsKey(s.id)) _put(runner.session);
  }
}

/// Named ping targets.
class SavedTargetsRepository {
  SavedTargetsRepository(this.db);
  final AppDatabase db;

  Stream<List<SavedTarget>> watch() => (db.select(
    db.savedTargets,
  )..orderBy([(t) => OrderingTerm.asc(t.sortOrder), (t) => OrderingTerm.asc(t.name)])).watch();

  Future<SavedTarget?> byHost(String host) =>
      (db.select(db.savedTargets)
            ..where((t) => t.host.lower().equals(host.toLowerCase()))
            ..limit(1))
          .getSingleOrNull();

  /// Marks [host] as used now; returns its saved entry if it has one.
  Future<SavedTarget?> touch(String host) async {
    final t = await byHost(host);
    if (t == null) return null;
    await (db.update(
      db.savedTargets,
    )..where((x) => x.id.equals(t.id))).write(SavedTargetsCompanion(lastUsedAt: Value(DateTime.now())));
    return t;
  }

  Future<int> add(String name, String host) async {
    final existing = await byHost(host.trim());
    if (existing != null) {
      await update(existing.id, name: name, host: host);
      return existing.id;
    }
    final count = await db.savedTargets.count().getSingle();
    return db
        .into(db.savedTargets)
        .insert(
          SavedTargetsCompanion.insert(
            name: name.trim(),
            host: host.trim(),
            sortOrder: Value(count),
            createdAt: DateTime.now(),
          ),
        );
  }

  Future<void> update(int id, {required String name, required String host}) => (db.update(
    db.savedTargets,
  )..where((t) => t.id.equals(id))).write(SavedTargetsCompanion(name: Value(name.trim()), host: Value(host.trim())));

  Future<void> delete(int id) => (db.delete(db.savedTargets)..where((t) => t.id.equals(id))).go();
}

final savedTargetsRepositoryProvider = Provider<SavedTargetsRepository>(
  (ref) => SavedTargetsRepository(ref.watch(databaseProvider)),
);

final savedTargetsProvider = StreamProvider<List<SavedTarget>>(
  (ref) => ref.watch(savedTargetsRepositoryProvider).watch(),
);

/// Recently pinged targets with their last average, newest first.
final recentTargetsProvider = StreamProvider<List<({String host, String? name, double? avg})>>((ref) {
  final db = ref.watch(databaseProvider);
  final q = db.select(db.sessions)
    ..where((s) => s.tool.equals(SessionTool.ping.name))
    ..orderBy([(s) => OrderingTerm.desc(s.startedAt)])
    ..limit(60);
  return q.watch().map((rows) {
    final seen = <String>{};
    final out = <({String host, String? name, double? avg})>[];
    for (final r in rows) {
      if (seen.add(r.target.toLowerCase())) {
        out.add((host: r.target, name: r.label, avg: r.avgMs));
      }
      if (out.length == 8) break;
    }
    return out;
  });
});

/// The editable target/name/params behind the Configure view.
@immutable
class PingDraft {
  const PingDraft({this.host = '', this.name = '', required this.params});
  final String host;
  final String name;
  final PingParams params;

  PingDraft copyWith({String? host, String? name, PingParams? params}) =>
      PingDraft(host: host ?? this.host, name: name ?? this.name, params: params ?? this.params);
}

final pingDraftProvider = NotifierProvider<PingDraftNotifier, PingDraft>(PingDraftNotifier.new);

class PingDraftNotifier extends Notifier<PingDraft> {
  @override
  PingDraft build() => PingDraft(params: PingParams.fromSettings(ref.read(settingsProvider)));

  void setHost(String v) => state = state.copyWith(host: v);
  void setName(String v) => state = state.copyWith(name: v);

  Future<void> setParams(PingParams p) async {
    state = state.copyWith(params: p);
    final settings = ref.read(settingsProvider);
    if (settings.saveAsDefault) {
      await ref
          .read(settingsProvider.notifier)
          .update(
            (s) => s.copyWith(
              pingCount: p.count,
              pingIntervalMs: p.intervalMs,
              pingTimeoutSec: p.timeoutSec,
              packetSize: p.packetSize,
              ipVersion: p.ipVersion,
            ),
          );
    }
  }

  void reset() => state = PingDraft(host: state.host, params: PingParams.fromSettings(const AppSettings()));
}
