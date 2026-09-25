// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $SessionsTable extends Sessions with TableInfo<$SessionsTable, Session> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'),
  );
  static const VerificationMeta _toolMeta = const VerificationMeta('tool');
  @override
  late final GeneratedColumn<String> tool = GeneratedColumn<String>(
    'tool',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _targetMeta = const VerificationMeta('target');
  @override
  late final GeneratedColumn<String> target = GeneratedColumn<String>(
    'target',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta('startedAt');
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endedAtMeta = const VerificationMeta('endedAt');
  @override
  late final GeneratedColumn<DateTime> endedAt = GeneratedColumn<DateTime>(
    'ended_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _avgMsMeta = const VerificationMeta('avgMs');
  @override
  late final GeneratedColumn<double> avgMs = GeneratedColumn<double>(
    'avg_ms',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lossPctMeta = const VerificationMeta('lossPct');
  @override
  late final GeneratedColumn<double> lossPct = GeneratedColumn<double>(
    'loss_pct',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _summaryMeta = const VerificationMeta('summary');
  @override
  late final GeneratedColumn<String> summary = GeneratedColumn<String>(
    'summary',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _trendMeta = const VerificationMeta('trend');
  @override
  late final GeneratedColumn<String> trend = GeneratedColumn<String>(
    'trend',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta('payload');
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    tool,
    target,
    label,
    startedAt,
    endedAt,
    avgMs,
    lossPct,
    summary,
    trend,
    payload,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sessions';
  @override
  VerificationContext validateIntegrity(Insertable<Session> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('tool')) {
      context.handle(_toolMeta, tool.isAcceptableOrUnknown(data['tool']!, _toolMeta));
    } else if (isInserting) {
      context.missing(_toolMeta);
    }
    if (data.containsKey('target')) {
      context.handle(_targetMeta, target.isAcceptableOrUnknown(data['target']!, _targetMeta));
    } else if (isInserting) {
      context.missing(_targetMeta);
    }
    if (data.containsKey('label')) {
      context.handle(_labelMeta, label.isAcceptableOrUnknown(data['label']!, _labelMeta));
    }
    if (data.containsKey('started_at')) {
      context.handle(_startedAtMeta, startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta));
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('ended_at')) {
      context.handle(_endedAtMeta, endedAt.isAcceptableOrUnknown(data['ended_at']!, _endedAtMeta));
    } else if (isInserting) {
      context.missing(_endedAtMeta);
    }
    if (data.containsKey('avg_ms')) {
      context.handle(_avgMsMeta, avgMs.isAcceptableOrUnknown(data['avg_ms']!, _avgMsMeta));
    }
    if (data.containsKey('loss_pct')) {
      context.handle(_lossPctMeta, lossPct.isAcceptableOrUnknown(data['loss_pct']!, _lossPctMeta));
    }
    if (data.containsKey('summary')) {
      context.handle(_summaryMeta, summary.isAcceptableOrUnknown(data['summary']!, _summaryMeta));
    }
    if (data.containsKey('trend')) {
      context.handle(_trendMeta, trend.isAcceptableOrUnknown(data['trend']!, _trendMeta));
    }
    if (data.containsKey('payload')) {
      context.handle(_payloadMeta, payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Session map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Session(
      id: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      tool: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}tool'])!,
      target: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}target'])!,
      label: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}label']),
      startedAt: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}started_at'])!,
      endedAt: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}ended_at'])!,
      avgMs: attachedDatabase.typeMapping.read(DriftSqlType.double, data['${effectivePrefix}avg_ms']),
      lossPct: attachedDatabase.typeMapping.read(DriftSqlType.double, data['${effectivePrefix}loss_pct']),
      summary: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}summary'])!,
      trend: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}trend'])!,
      payload: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}payload'])!,
    );
  }

  @override
  $SessionsTable createAlias(String alias) {
    return $SessionsTable(attachedDatabase, alias);
  }
}

class Session extends DataClass implements Insertable<Session> {
  final int id;

  /// One of [SessionTool] names.
  final String tool;
  final String target;

  /// User-given name, e.g. "Office PC" (schema v2).
  final String? label;
  final DateTime startedAt;
  final DateTime endedAt;
  final double? avgMs;
  final double? lossPct;

  /// Short one-line result for lists, e.g. "24 MS · 0%".
  final String summary;

  /// JSON array of up to 12 numbers for the sparkline.
  final String trend;

  /// Tool-specific JSON with the complete result.
  final String payload;
  const Session({
    required this.id,
    required this.tool,
    required this.target,
    this.label,
    required this.startedAt,
    required this.endedAt,
    this.avgMs,
    this.lossPct,
    required this.summary,
    required this.trend,
    required this.payload,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['tool'] = Variable<String>(tool);
    map['target'] = Variable<String>(target);
    if (!nullToAbsent || label != null) {
      map['label'] = Variable<String>(label);
    }
    map['started_at'] = Variable<DateTime>(startedAt);
    map['ended_at'] = Variable<DateTime>(endedAt);
    if (!nullToAbsent || avgMs != null) {
      map['avg_ms'] = Variable<double>(avgMs);
    }
    if (!nullToAbsent || lossPct != null) {
      map['loss_pct'] = Variable<double>(lossPct);
    }
    map['summary'] = Variable<String>(summary);
    map['trend'] = Variable<String>(trend);
    map['payload'] = Variable<String>(payload);
    return map;
  }

  SessionsCompanion toCompanion(bool nullToAbsent) {
    return SessionsCompanion(
      id: Value(id),
      tool: Value(tool),
      target: Value(target),
      label: label == null && nullToAbsent ? const Value.absent() : Value(label),
      startedAt: Value(startedAt),
      endedAt: Value(endedAt),
      avgMs: avgMs == null && nullToAbsent ? const Value.absent() : Value(avgMs),
      lossPct: lossPct == null && nullToAbsent ? const Value.absent() : Value(lossPct),
      summary: Value(summary),
      trend: Value(trend),
      payload: Value(payload),
    );
  }

  factory Session.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Session(
      id: serializer.fromJson<int>(json['id']),
      tool: serializer.fromJson<String>(json['tool']),
      target: serializer.fromJson<String>(json['target']),
      label: serializer.fromJson<String?>(json['label']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
      endedAt: serializer.fromJson<DateTime>(json['endedAt']),
      avgMs: serializer.fromJson<double?>(json['avgMs']),
      lossPct: serializer.fromJson<double?>(json['lossPct']),
      summary: serializer.fromJson<String>(json['summary']),
      trend: serializer.fromJson<String>(json['trend']),
      payload: serializer.fromJson<String>(json['payload']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'tool': serializer.toJson<String>(tool),
      'target': serializer.toJson<String>(target),
      'label': serializer.toJson<String?>(label),
      'startedAt': serializer.toJson<DateTime>(startedAt),
      'endedAt': serializer.toJson<DateTime>(endedAt),
      'avgMs': serializer.toJson<double?>(avgMs),
      'lossPct': serializer.toJson<double?>(lossPct),
      'summary': serializer.toJson<String>(summary),
      'trend': serializer.toJson<String>(trend),
      'payload': serializer.toJson<String>(payload),
    };
  }

  Session copyWith({
    int? id,
    String? tool,
    String? target,
    Value<String?> label = const Value.absent(),
    DateTime? startedAt,
    DateTime? endedAt,
    Value<double?> avgMs = const Value.absent(),
    Value<double?> lossPct = const Value.absent(),
    String? summary,
    String? trend,
    String? payload,
  }) => Session(
    id: id ?? this.id,
    tool: tool ?? this.tool,
    target: target ?? this.target,
    label: label.present ? label.value : this.label,
    startedAt: startedAt ?? this.startedAt,
    endedAt: endedAt ?? this.endedAt,
    avgMs: avgMs.present ? avgMs.value : this.avgMs,
    lossPct: lossPct.present ? lossPct.value : this.lossPct,
    summary: summary ?? this.summary,
    trend: trend ?? this.trend,
    payload: payload ?? this.payload,
  );
  Session copyWithCompanion(SessionsCompanion data) {
    return Session(
      id: data.id.present ? data.id.value : this.id,
      tool: data.tool.present ? data.tool.value : this.tool,
      target: data.target.present ? data.target.value : this.target,
      label: data.label.present ? data.label.value : this.label,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      endedAt: data.endedAt.present ? data.endedAt.value : this.endedAt,
      avgMs: data.avgMs.present ? data.avgMs.value : this.avgMs,
      lossPct: data.lossPct.present ? data.lossPct.value : this.lossPct,
      summary: data.summary.present ? data.summary.value : this.summary,
      trend: data.trend.present ? data.trend.value : this.trend,
      payload: data.payload.present ? data.payload.value : this.payload,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Session(')
          ..write('id: $id, ')
          ..write('tool: $tool, ')
          ..write('target: $target, ')
          ..write('label: $label, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('avgMs: $avgMs, ')
          ..write('lossPct: $lossPct, ')
          ..write('summary: $summary, ')
          ..write('trend: $trend, ')
          ..write('payload: $payload')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, tool, target, label, startedAt, endedAt, avgMs, lossPct, summary, trend, payload);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Session &&
          other.id == this.id &&
          other.tool == this.tool &&
          other.target == this.target &&
          other.label == this.label &&
          other.startedAt == this.startedAt &&
          other.endedAt == this.endedAt &&
          other.avgMs == this.avgMs &&
          other.lossPct == this.lossPct &&
          other.summary == this.summary &&
          other.trend == this.trend &&
          other.payload == this.payload);
}

class SessionsCompanion extends UpdateCompanion<Session> {
  final Value<int> id;
  final Value<String> tool;
  final Value<String> target;
  final Value<String?> label;
  final Value<DateTime> startedAt;
  final Value<DateTime> endedAt;
  final Value<double?> avgMs;
  final Value<double?> lossPct;
  final Value<String> summary;
  final Value<String> trend;
  final Value<String> payload;
  const SessionsCompanion({
    this.id = const Value.absent(),
    this.tool = const Value.absent(),
    this.target = const Value.absent(),
    this.label = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.endedAt = const Value.absent(),
    this.avgMs = const Value.absent(),
    this.lossPct = const Value.absent(),
    this.summary = const Value.absent(),
    this.trend = const Value.absent(),
    this.payload = const Value.absent(),
  });
  SessionsCompanion.insert({
    this.id = const Value.absent(),
    required String tool,
    required String target,
    this.label = const Value.absent(),
    required DateTime startedAt,
    required DateTime endedAt,
    this.avgMs = const Value.absent(),
    this.lossPct = const Value.absent(),
    this.summary = const Value.absent(),
    this.trend = const Value.absent(),
    this.payload = const Value.absent(),
  }) : tool = Value(tool),
       target = Value(target),
       startedAt = Value(startedAt),
       endedAt = Value(endedAt);
  static Insertable<Session> custom({
    Expression<int>? id,
    Expression<String>? tool,
    Expression<String>? target,
    Expression<String>? label,
    Expression<DateTime>? startedAt,
    Expression<DateTime>? endedAt,
    Expression<double>? avgMs,
    Expression<double>? lossPct,
    Expression<String>? summary,
    Expression<String>? trend,
    Expression<String>? payload,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (tool != null) 'tool': tool,
      if (target != null) 'target': target,
      if (label != null) 'label': label,
      if (startedAt != null) 'started_at': startedAt,
      if (endedAt != null) 'ended_at': endedAt,
      if (avgMs != null) 'avg_ms': avgMs,
      if (lossPct != null) 'loss_pct': lossPct,
      if (summary != null) 'summary': summary,
      if (trend != null) 'trend': trend,
      if (payload != null) 'payload': payload,
    });
  }

  SessionsCompanion copyWith({
    Value<int>? id,
    Value<String>? tool,
    Value<String>? target,
    Value<String?>? label,
    Value<DateTime>? startedAt,
    Value<DateTime>? endedAt,
    Value<double?>? avgMs,
    Value<double?>? lossPct,
    Value<String>? summary,
    Value<String>? trend,
    Value<String>? payload,
  }) {
    return SessionsCompanion(
      id: id ?? this.id,
      tool: tool ?? this.tool,
      target: target ?? this.target,
      label: label ?? this.label,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      avgMs: avgMs ?? this.avgMs,
      lossPct: lossPct ?? this.lossPct,
      summary: summary ?? this.summary,
      trend: trend ?? this.trend,
      payload: payload ?? this.payload,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (tool.present) {
      map['tool'] = Variable<String>(tool.value);
    }
    if (target.present) {
      map['target'] = Variable<String>(target.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (endedAt.present) {
      map['ended_at'] = Variable<DateTime>(endedAt.value);
    }
    if (avgMs.present) {
      map['avg_ms'] = Variable<double>(avgMs.value);
    }
    if (lossPct.present) {
      map['loss_pct'] = Variable<double>(lossPct.value);
    }
    if (summary.present) {
      map['summary'] = Variable<String>(summary.value);
    }
    if (trend.present) {
      map['trend'] = Variable<String>(trend.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SessionsCompanion(')
          ..write('id: $id, ')
          ..write('tool: $tool, ')
          ..write('target: $target, ')
          ..write('label: $label, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('avgMs: $avgMs, ')
          ..write('lossPct: $lossPct, ')
          ..write('summary: $summary, ')
          ..write('trend: $trend, ')
          ..write('payload: $payload')
          ..write(')'))
        .toString();
  }
}

class $SavedTargetsTable extends SavedTargets with TableInfo<$SavedTargetsTable, SavedTarget> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SavedTargetsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _hostMeta = const VerificationMeta('host');
  @override
  late final GeneratedColumn<String> host = GeneratedColumn<String>(
    'host',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta('sortOrder');
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastUsedAtMeta = const VerificationMeta('lastUsedAt');
  @override
  late final GeneratedColumn<DateTime> lastUsedAt = GeneratedColumn<DateTime>(
    'last_used_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, host, sortOrder, createdAt, lastUsedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'saved_targets';
  @override
  VerificationContext validateIntegrity(Insertable<SavedTarget> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(_nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('host')) {
      context.handle(_hostMeta, host.isAcceptableOrUnknown(data['host']!, _hostMeta));
    } else if (isInserting) {
      context.missing(_hostMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(_sortOrderMeta, sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta, createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('last_used_at')) {
      context.handle(_lastUsedAtMeta, lastUsedAt.isAcceptableOrUnknown(data['last_used_at']!, _lastUsedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SavedTarget map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SavedTarget(
      id: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      host: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}host'])!,
      sortOrder: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}sort_order'])!,
      createdAt: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      lastUsedAt: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}last_used_at']),
    );
  }

  @override
  $SavedTargetsTable createAlias(String alias) {
    return $SavedTargetsTable(attachedDatabase, alias);
  }
}

class SavedTarget extends DataClass implements Insertable<SavedTarget> {
  final int id;
  final String name;
  final String host;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime? lastUsedAt;
  const SavedTarget({
    required this.id,
    required this.name,
    required this.host,
    required this.sortOrder,
    required this.createdAt,
    this.lastUsedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['host'] = Variable<String>(host);
    map['sort_order'] = Variable<int>(sortOrder);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || lastUsedAt != null) {
      map['last_used_at'] = Variable<DateTime>(lastUsedAt);
    }
    return map;
  }

  SavedTargetsCompanion toCompanion(bool nullToAbsent) {
    return SavedTargetsCompanion(
      id: Value(id),
      name: Value(name),
      host: Value(host),
      sortOrder: Value(sortOrder),
      createdAt: Value(createdAt),
      lastUsedAt: lastUsedAt == null && nullToAbsent ? const Value.absent() : Value(lastUsedAt),
    );
  }

  factory SavedTarget.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SavedTarget(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      host: serializer.fromJson<String>(json['host']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      lastUsedAt: serializer.fromJson<DateTime?>(json['lastUsedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'host': serializer.toJson<String>(host),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'lastUsedAt': serializer.toJson<DateTime?>(lastUsedAt),
    };
  }

  SavedTarget copyWith({
    int? id,
    String? name,
    String? host,
    int? sortOrder,
    DateTime? createdAt,
    Value<DateTime?> lastUsedAt = const Value.absent(),
  }) => SavedTarget(
    id: id ?? this.id,
    name: name ?? this.name,
    host: host ?? this.host,
    sortOrder: sortOrder ?? this.sortOrder,
    createdAt: createdAt ?? this.createdAt,
    lastUsedAt: lastUsedAt.present ? lastUsedAt.value : this.lastUsedAt,
  );
  SavedTarget copyWithCompanion(SavedTargetsCompanion data) {
    return SavedTarget(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      host: data.host.present ? data.host.value : this.host,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      lastUsedAt: data.lastUsedAt.present ? data.lastUsedAt.value : this.lastUsedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SavedTarget(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('host: $host, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastUsedAt: $lastUsedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, host, sortOrder, createdAt, lastUsedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SavedTarget &&
          other.id == this.id &&
          other.name == this.name &&
          other.host == this.host &&
          other.sortOrder == this.sortOrder &&
          other.createdAt == this.createdAt &&
          other.lastUsedAt == this.lastUsedAt);
}

class SavedTargetsCompanion extends UpdateCompanion<SavedTarget> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> host;
  final Value<int> sortOrder;
  final Value<DateTime> createdAt;
  final Value<DateTime?> lastUsedAt;
  const SavedTargetsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.host = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.lastUsedAt = const Value.absent(),
  });
  SavedTargetsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required String host,
    this.sortOrder = const Value.absent(),
    required DateTime createdAt,
    this.lastUsedAt = const Value.absent(),
  }) : name = Value(name),
       host = Value(host),
       createdAt = Value(createdAt);
  static Insertable<SavedTarget> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? host,
    Expression<int>? sortOrder,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? lastUsedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (host != null) 'host': host,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (createdAt != null) 'created_at': createdAt,
      if (lastUsedAt != null) 'last_used_at': lastUsedAt,
    });
  }

  SavedTargetsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String>? host,
    Value<int>? sortOrder,
    Value<DateTime>? createdAt,
    Value<DateTime?>? lastUsedAt,
  }) {
    return SavedTargetsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      host: host ?? this.host,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (host.present) {
      map['host'] = Variable<String>(host.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (lastUsedAt.present) {
      map['last_used_at'] = Variable<DateTime>(lastUsedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SavedTargetsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('host: $host, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastUsedAt: $lastUsedAt')
          ..write(')'))
        .toString();
  }
}

class $MonitorTargetsTable extends MonitorTargets with TableInfo<$MonitorTargetsTable, MonitorTarget> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MonitorTargetsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'),
  );
  static const VerificationMeta _hostMeta = const VerificationMeta('host');
  @override
  late final GeneratedColumn<String> host = GeneratedColumn<String>(
    'host',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _enabledMeta = const VerificationMeta('enabled');
  @override
  late final GeneratedColumn<bool> enabled = GeneratedColumn<bool>(
    'enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('CHECK ("enabled" IN (0, 1))'),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta('sortOrder');
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, host, name, enabled, sortOrder, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'monitor_targets';
  @override
  VerificationContext validateIntegrity(Insertable<MonitorTarget> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('host')) {
      context.handle(_hostMeta, host.isAcceptableOrUnknown(data['host']!, _hostMeta));
    } else if (isInserting) {
      context.missing(_hostMeta);
    }
    if (data.containsKey('name')) {
      context.handle(_nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('enabled')) {
      context.handle(_enabledMeta, enabled.isAcceptableOrUnknown(data['enabled']!, _enabledMeta));
    }
    if (data.containsKey('sort_order')) {
      context.handle(_sortOrderMeta, sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta, createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MonitorTarget map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MonitorTarget(
      id: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      host: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}host'])!,
      name: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      enabled: attachedDatabase.typeMapping.read(DriftSqlType.bool, data['${effectivePrefix}enabled'])!,
      sortOrder: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}sort_order'])!,
      createdAt: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $MonitorTargetsTable createAlias(String alias) {
    return $MonitorTargetsTable(attachedDatabase, alias);
  }
}

class MonitorTarget extends DataClass implements Insertable<MonitorTarget> {
  final int id;
  final String host;
  final String name;
  final bool enabled;
  final int sortOrder;
  final DateTime createdAt;
  const MonitorTarget({
    required this.id,
    required this.host,
    required this.name,
    required this.enabled,
    required this.sortOrder,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['host'] = Variable<String>(host);
    map['name'] = Variable<String>(name);
    map['enabled'] = Variable<bool>(enabled);
    map['sort_order'] = Variable<int>(sortOrder);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  MonitorTargetsCompanion toCompanion(bool nullToAbsent) {
    return MonitorTargetsCompanion(
      id: Value(id),
      host: Value(host),
      name: Value(name),
      enabled: Value(enabled),
      sortOrder: Value(sortOrder),
      createdAt: Value(createdAt),
    );
  }

  factory MonitorTarget.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MonitorTarget(
      id: serializer.fromJson<int>(json['id']),
      host: serializer.fromJson<String>(json['host']),
      name: serializer.fromJson<String>(json['name']),
      enabled: serializer.fromJson<bool>(json['enabled']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'host': serializer.toJson<String>(host),
      'name': serializer.toJson<String>(name),
      'enabled': serializer.toJson<bool>(enabled),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  MonitorTarget copyWith({int? id, String? host, String? name, bool? enabled, int? sortOrder, DateTime? createdAt}) =>
      MonitorTarget(
        id: id ?? this.id,
        host: host ?? this.host,
        name: name ?? this.name,
        enabled: enabled ?? this.enabled,
        sortOrder: sortOrder ?? this.sortOrder,
        createdAt: createdAt ?? this.createdAt,
      );
  MonitorTarget copyWithCompanion(MonitorTargetsCompanion data) {
    return MonitorTarget(
      id: data.id.present ? data.id.value : this.id,
      host: data.host.present ? data.host.value : this.host,
      name: data.name.present ? data.name.value : this.name,
      enabled: data.enabled.present ? data.enabled.value : this.enabled,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MonitorTarget(')
          ..write('id: $id, ')
          ..write('host: $host, ')
          ..write('name: $name, ')
          ..write('enabled: $enabled, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, host, name, enabled, sortOrder, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MonitorTarget &&
          other.id == this.id &&
          other.host == this.host &&
          other.name == this.name &&
          other.enabled == this.enabled &&
          other.sortOrder == this.sortOrder &&
          other.createdAt == this.createdAt);
}

class MonitorTargetsCompanion extends UpdateCompanion<MonitorTarget> {
  final Value<int> id;
  final Value<String> host;
  final Value<String> name;
  final Value<bool> enabled;
  final Value<int> sortOrder;
  final Value<DateTime> createdAt;
  const MonitorTargetsCompanion({
    this.id = const Value.absent(),
    this.host = const Value.absent(),
    this.name = const Value.absent(),
    this.enabled = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  MonitorTargetsCompanion.insert({
    this.id = const Value.absent(),
    required String host,
    required String name,
    this.enabled = const Value.absent(),
    this.sortOrder = const Value.absent(),
    required DateTime createdAt,
  }) : host = Value(host),
       name = Value(name),
       createdAt = Value(createdAt);
  static Insertable<MonitorTarget> custom({
    Expression<int>? id,
    Expression<String>? host,
    Expression<String>? name,
    Expression<bool>? enabled,
    Expression<int>? sortOrder,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (host != null) 'host': host,
      if (name != null) 'name': name,
      if (enabled != null) 'enabled': enabled,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  MonitorTargetsCompanion copyWith({
    Value<int>? id,
    Value<String>? host,
    Value<String>? name,
    Value<bool>? enabled,
    Value<int>? sortOrder,
    Value<DateTime>? createdAt,
  }) {
    return MonitorTargetsCompanion(
      id: id ?? this.id,
      host: host ?? this.host,
      name: name ?? this.name,
      enabled: enabled ?? this.enabled,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (host.present) {
      map['host'] = Variable<String>(host.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (enabled.present) {
      map['enabled'] = Variable<bool>(enabled.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MonitorTargetsCompanion(')
          ..write('id: $id, ')
          ..write('host: $host, ')
          ..write('name: $name, ')
          ..write('enabled: $enabled, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $MonitorChecksTable extends MonitorChecks with TableInfo<$MonitorChecksTable, MonitorCheck> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MonitorChecksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'),
  );
  static const VerificationMeta _targetIdMeta = const VerificationMeta('targetId');
  @override
  late final GeneratedColumn<int> targetId = GeneratedColumn<int>(
    'target_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('REFERENCES monitor_targets (id) ON DELETE CASCADE'),
  );
  static const VerificationMeta _atMeta = const VerificationMeta('at');
  @override
  late final GeneratedColumn<DateTime> at = GeneratedColumn<DateTime>(
    'at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sentMeta = const VerificationMeta('sent');
  @override
  late final GeneratedColumn<int> sent = GeneratedColumn<int>(
    'sent',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _receivedMeta = const VerificationMeta('received');
  @override
  late final GeneratedColumn<int> received = GeneratedColumn<int>(
    'received',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rttAvgMeta = const VerificationMeta('rttAvg');
  @override
  late final GeneratedColumn<double> rttAvg = GeneratedColumn<double>(
    'rtt_avg',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _rttMaxMeta = const VerificationMeta('rttMax');
  @override
  late final GeneratedColumn<double> rttMax = GeneratedColumn<double>(
    'rtt_max',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [id, targetId, at, sent, received, rttAvg, rttMax];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'monitor_checks';
  @override
  VerificationContext validateIntegrity(Insertable<MonitorCheck> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('target_id')) {
      context.handle(_targetIdMeta, targetId.isAcceptableOrUnknown(data['target_id']!, _targetIdMeta));
    } else if (isInserting) {
      context.missing(_targetIdMeta);
    }
    if (data.containsKey('at')) {
      context.handle(_atMeta, at.isAcceptableOrUnknown(data['at']!, _atMeta));
    } else if (isInserting) {
      context.missing(_atMeta);
    }
    if (data.containsKey('sent')) {
      context.handle(_sentMeta, sent.isAcceptableOrUnknown(data['sent']!, _sentMeta));
    } else if (isInserting) {
      context.missing(_sentMeta);
    }
    if (data.containsKey('received')) {
      context.handle(_receivedMeta, received.isAcceptableOrUnknown(data['received']!, _receivedMeta));
    } else if (isInserting) {
      context.missing(_receivedMeta);
    }
    if (data.containsKey('rtt_avg')) {
      context.handle(_rttAvgMeta, rttAvg.isAcceptableOrUnknown(data['rtt_avg']!, _rttAvgMeta));
    }
    if (data.containsKey('rtt_max')) {
      context.handle(_rttMaxMeta, rttMax.isAcceptableOrUnknown(data['rtt_max']!, _rttMaxMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MonitorCheck map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MonitorCheck(
      id: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      targetId: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}target_id'])!,
      at: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}at'])!,
      sent: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}sent'])!,
      received: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}received'])!,
      rttAvg: attachedDatabase.typeMapping.read(DriftSqlType.double, data['${effectivePrefix}rtt_avg']),
      rttMax: attachedDatabase.typeMapping.read(DriftSqlType.double, data['${effectivePrefix}rtt_max']),
    );
  }

  @override
  $MonitorChecksTable createAlias(String alias) {
    return $MonitorChecksTable(attachedDatabase, alias);
  }
}

class MonitorCheck extends DataClass implements Insertable<MonitorCheck> {
  final int id;
  final int targetId;
  final DateTime at;
  final int sent;
  final int received;
  final double? rttAvg;
  final double? rttMax;
  const MonitorCheck({
    required this.id,
    required this.targetId,
    required this.at,
    required this.sent,
    required this.received,
    this.rttAvg,
    this.rttMax,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['target_id'] = Variable<int>(targetId);
    map['at'] = Variable<DateTime>(at);
    map['sent'] = Variable<int>(sent);
    map['received'] = Variable<int>(received);
    if (!nullToAbsent || rttAvg != null) {
      map['rtt_avg'] = Variable<double>(rttAvg);
    }
    if (!nullToAbsent || rttMax != null) {
      map['rtt_max'] = Variable<double>(rttMax);
    }
    return map;
  }

  MonitorChecksCompanion toCompanion(bool nullToAbsent) {
    return MonitorChecksCompanion(
      id: Value(id),
      targetId: Value(targetId),
      at: Value(at),
      sent: Value(sent),
      received: Value(received),
      rttAvg: rttAvg == null && nullToAbsent ? const Value.absent() : Value(rttAvg),
      rttMax: rttMax == null && nullToAbsent ? const Value.absent() : Value(rttMax),
    );
  }

  factory MonitorCheck.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MonitorCheck(
      id: serializer.fromJson<int>(json['id']),
      targetId: serializer.fromJson<int>(json['targetId']),
      at: serializer.fromJson<DateTime>(json['at']),
      sent: serializer.fromJson<int>(json['sent']),
      received: serializer.fromJson<int>(json['received']),
      rttAvg: serializer.fromJson<double?>(json['rttAvg']),
      rttMax: serializer.fromJson<double?>(json['rttMax']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'targetId': serializer.toJson<int>(targetId),
      'at': serializer.toJson<DateTime>(at),
      'sent': serializer.toJson<int>(sent),
      'received': serializer.toJson<int>(received),
      'rttAvg': serializer.toJson<double?>(rttAvg),
      'rttMax': serializer.toJson<double?>(rttMax),
    };
  }

  MonitorCheck copyWith({
    int? id,
    int? targetId,
    DateTime? at,
    int? sent,
    int? received,
    Value<double?> rttAvg = const Value.absent(),
    Value<double?> rttMax = const Value.absent(),
  }) => MonitorCheck(
    id: id ?? this.id,
    targetId: targetId ?? this.targetId,
    at: at ?? this.at,
    sent: sent ?? this.sent,
    received: received ?? this.received,
    rttAvg: rttAvg.present ? rttAvg.value : this.rttAvg,
    rttMax: rttMax.present ? rttMax.value : this.rttMax,
  );
  MonitorCheck copyWithCompanion(MonitorChecksCompanion data) {
    return MonitorCheck(
      id: data.id.present ? data.id.value : this.id,
      targetId: data.targetId.present ? data.targetId.value : this.targetId,
      at: data.at.present ? data.at.value : this.at,
      sent: data.sent.present ? data.sent.value : this.sent,
      received: data.received.present ? data.received.value : this.received,
      rttAvg: data.rttAvg.present ? data.rttAvg.value : this.rttAvg,
      rttMax: data.rttMax.present ? data.rttMax.value : this.rttMax,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MonitorCheck(')
          ..write('id: $id, ')
          ..write('targetId: $targetId, ')
          ..write('at: $at, ')
          ..write('sent: $sent, ')
          ..write('received: $received, ')
          ..write('rttAvg: $rttAvg, ')
          ..write('rttMax: $rttMax')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, targetId, at, sent, received, rttAvg, rttMax);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MonitorCheck &&
          other.id == this.id &&
          other.targetId == this.targetId &&
          other.at == this.at &&
          other.sent == this.sent &&
          other.received == this.received &&
          other.rttAvg == this.rttAvg &&
          other.rttMax == this.rttMax);
}

class MonitorChecksCompanion extends UpdateCompanion<MonitorCheck> {
  final Value<int> id;
  final Value<int> targetId;
  final Value<DateTime> at;
  final Value<int> sent;
  final Value<int> received;
  final Value<double?> rttAvg;
  final Value<double?> rttMax;
  const MonitorChecksCompanion({
    this.id = const Value.absent(),
    this.targetId = const Value.absent(),
    this.at = const Value.absent(),
    this.sent = const Value.absent(),
    this.received = const Value.absent(),
    this.rttAvg = const Value.absent(),
    this.rttMax = const Value.absent(),
  });
  MonitorChecksCompanion.insert({
    this.id = const Value.absent(),
    required int targetId,
    required DateTime at,
    required int sent,
    required int received,
    this.rttAvg = const Value.absent(),
    this.rttMax = const Value.absent(),
  }) : targetId = Value(targetId),
       at = Value(at),
       sent = Value(sent),
       received = Value(received);
  static Insertable<MonitorCheck> custom({
    Expression<int>? id,
    Expression<int>? targetId,
    Expression<DateTime>? at,
    Expression<int>? sent,
    Expression<int>? received,
    Expression<double>? rttAvg,
    Expression<double>? rttMax,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (targetId != null) 'target_id': targetId,
      if (at != null) 'at': at,
      if (sent != null) 'sent': sent,
      if (received != null) 'received': received,
      if (rttAvg != null) 'rtt_avg': rttAvg,
      if (rttMax != null) 'rtt_max': rttMax,
    });
  }

  MonitorChecksCompanion copyWith({
    Value<int>? id,
    Value<int>? targetId,
    Value<DateTime>? at,
    Value<int>? sent,
    Value<int>? received,
    Value<double?>? rttAvg,
    Value<double?>? rttMax,
  }) {
    return MonitorChecksCompanion(
      id: id ?? this.id,
      targetId: targetId ?? this.targetId,
      at: at ?? this.at,
      sent: sent ?? this.sent,
      received: received ?? this.received,
      rttAvg: rttAvg ?? this.rttAvg,
      rttMax: rttMax ?? this.rttMax,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (targetId.present) {
      map['target_id'] = Variable<int>(targetId.value);
    }
    if (at.present) {
      map['at'] = Variable<DateTime>(at.value);
    }
    if (sent.present) {
      map['sent'] = Variable<int>(sent.value);
    }
    if (received.present) {
      map['received'] = Variable<int>(received.value);
    }
    if (rttAvg.present) {
      map['rtt_avg'] = Variable<double>(rttAvg.value);
    }
    if (rttMax.present) {
      map['rtt_max'] = Variable<double>(rttMax.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MonitorChecksCompanion(')
          ..write('id: $id, ')
          ..write('targetId: $targetId, ')
          ..write('at: $at, ')
          ..write('sent: $sent, ')
          ..write('received: $received, ')
          ..write('rttAvg: $rttAvg, ')
          ..write('rttMax: $rttMax')
          ..write(')'))
        .toString();
  }
}

class $IncidentsTable extends Incidents with TableInfo<$IncidentsTable, Incident> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $IncidentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'),
  );
  static const VerificationMeta _targetIdMeta = const VerificationMeta('targetId');
  @override
  late final GeneratedColumn<int> targetId = GeneratedColumn<int>(
    'target_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('REFERENCES monitor_targets (id) ON DELETE CASCADE'),
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta('description');
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta('startedAt');
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endedAtMeta = const VerificationMeta('endedAt');
  @override
  late final GeneratedColumn<DateTime> endedAt = GeneratedColumn<DateTime>(
    'ended_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _peakMeta = const VerificationMeta('peak');
  @override
  late final GeneratedColumn<double> peak = GeneratedColumn<double>(
    'peak',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _failedChecksMeta = const VerificationMeta('failedChecks');
  @override
  late final GeneratedColumn<int> failedChecks = GeneratedColumn<int>(
    'failed_checks',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    targetId,
    kind,
    title,
    description,
    startedAt,
    endedAt,
    peak,
    failedChecks,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'incidents';
  @override
  VerificationContext validateIntegrity(Insertable<Incident> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('target_id')) {
      context.handle(_targetIdMeta, targetId.isAcceptableOrUnknown(data['target_id']!, _targetIdMeta));
    } else if (isInserting) {
      context.missing(_targetIdMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(_kindMeta, kind.isAcceptableOrUnknown(data['kind']!, _kindMeta));
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('title')) {
      context.handle(_titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('description')) {
      context.handle(_descriptionMeta, description.isAcceptableOrUnknown(data['description']!, _descriptionMeta));
    } else if (isInserting) {
      context.missing(_descriptionMeta);
    }
    if (data.containsKey('started_at')) {
      context.handle(_startedAtMeta, startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta));
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('ended_at')) {
      context.handle(_endedAtMeta, endedAt.isAcceptableOrUnknown(data['ended_at']!, _endedAtMeta));
    }
    if (data.containsKey('peak')) {
      context.handle(_peakMeta, peak.isAcceptableOrUnknown(data['peak']!, _peakMeta));
    }
    if (data.containsKey('failed_checks')) {
      context.handle(_failedChecksMeta, failedChecks.isAcceptableOrUnknown(data['failed_checks']!, _failedChecksMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Incident map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Incident(
      id: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      targetId: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}target_id'])!,
      kind: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}kind'])!,
      title: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      description: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}description'])!,
      startedAt: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}started_at'])!,
      endedAt: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}ended_at']),
      peak: attachedDatabase.typeMapping.read(DriftSqlType.double, data['${effectivePrefix}peak']),
      failedChecks: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}failed_checks'])!,
    );
  }

  @override
  $IncidentsTable createAlias(String alias) {
    return $IncidentsTable(attachedDatabase, alias);
  }
}

class Incident extends DataClass implements Insertable<Incident> {
  final int id;
  final int targetId;

  /// down | loss | latency
  final String kind;
  final String title;
  final String description;
  final DateTime startedAt;
  final DateTime? endedAt;
  final double? peak;
  final int failedChecks;
  const Incident({
    required this.id,
    required this.targetId,
    required this.kind,
    required this.title,
    required this.description,
    required this.startedAt,
    this.endedAt,
    this.peak,
    required this.failedChecks,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['target_id'] = Variable<int>(targetId);
    map['kind'] = Variable<String>(kind);
    map['title'] = Variable<String>(title);
    map['description'] = Variable<String>(description);
    map['started_at'] = Variable<DateTime>(startedAt);
    if (!nullToAbsent || endedAt != null) {
      map['ended_at'] = Variable<DateTime>(endedAt);
    }
    if (!nullToAbsent || peak != null) {
      map['peak'] = Variable<double>(peak);
    }
    map['failed_checks'] = Variable<int>(failedChecks);
    return map;
  }

  IncidentsCompanion toCompanion(bool nullToAbsent) {
    return IncidentsCompanion(
      id: Value(id),
      targetId: Value(targetId),
      kind: Value(kind),
      title: Value(title),
      description: Value(description),
      startedAt: Value(startedAt),
      endedAt: endedAt == null && nullToAbsent ? const Value.absent() : Value(endedAt),
      peak: peak == null && nullToAbsent ? const Value.absent() : Value(peak),
      failedChecks: Value(failedChecks),
    );
  }

  factory Incident.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Incident(
      id: serializer.fromJson<int>(json['id']),
      targetId: serializer.fromJson<int>(json['targetId']),
      kind: serializer.fromJson<String>(json['kind']),
      title: serializer.fromJson<String>(json['title']),
      description: serializer.fromJson<String>(json['description']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
      endedAt: serializer.fromJson<DateTime?>(json['endedAt']),
      peak: serializer.fromJson<double?>(json['peak']),
      failedChecks: serializer.fromJson<int>(json['failedChecks']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'targetId': serializer.toJson<int>(targetId),
      'kind': serializer.toJson<String>(kind),
      'title': serializer.toJson<String>(title),
      'description': serializer.toJson<String>(description),
      'startedAt': serializer.toJson<DateTime>(startedAt),
      'endedAt': serializer.toJson<DateTime?>(endedAt),
      'peak': serializer.toJson<double?>(peak),
      'failedChecks': serializer.toJson<int>(failedChecks),
    };
  }

  Incident copyWith({
    int? id,
    int? targetId,
    String? kind,
    String? title,
    String? description,
    DateTime? startedAt,
    Value<DateTime?> endedAt = const Value.absent(),
    Value<double?> peak = const Value.absent(),
    int? failedChecks,
  }) => Incident(
    id: id ?? this.id,
    targetId: targetId ?? this.targetId,
    kind: kind ?? this.kind,
    title: title ?? this.title,
    description: description ?? this.description,
    startedAt: startedAt ?? this.startedAt,
    endedAt: endedAt.present ? endedAt.value : this.endedAt,
    peak: peak.present ? peak.value : this.peak,
    failedChecks: failedChecks ?? this.failedChecks,
  );
  Incident copyWithCompanion(IncidentsCompanion data) {
    return Incident(
      id: data.id.present ? data.id.value : this.id,
      targetId: data.targetId.present ? data.targetId.value : this.targetId,
      kind: data.kind.present ? data.kind.value : this.kind,
      title: data.title.present ? data.title.value : this.title,
      description: data.description.present ? data.description.value : this.description,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      endedAt: data.endedAt.present ? data.endedAt.value : this.endedAt,
      peak: data.peak.present ? data.peak.value : this.peak,
      failedChecks: data.failedChecks.present ? data.failedChecks.value : this.failedChecks,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Incident(')
          ..write('id: $id, ')
          ..write('targetId: $targetId, ')
          ..write('kind: $kind, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('peak: $peak, ')
          ..write('failedChecks: $failedChecks')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, targetId, kind, title, description, startedAt, endedAt, peak, failedChecks);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Incident &&
          other.id == this.id &&
          other.targetId == this.targetId &&
          other.kind == this.kind &&
          other.title == this.title &&
          other.description == this.description &&
          other.startedAt == this.startedAt &&
          other.endedAt == this.endedAt &&
          other.peak == this.peak &&
          other.failedChecks == this.failedChecks);
}

class IncidentsCompanion extends UpdateCompanion<Incident> {
  final Value<int> id;
  final Value<int> targetId;
  final Value<String> kind;
  final Value<String> title;
  final Value<String> description;
  final Value<DateTime> startedAt;
  final Value<DateTime?> endedAt;
  final Value<double?> peak;
  final Value<int> failedChecks;
  const IncidentsCompanion({
    this.id = const Value.absent(),
    this.targetId = const Value.absent(),
    this.kind = const Value.absent(),
    this.title = const Value.absent(),
    this.description = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.endedAt = const Value.absent(),
    this.peak = const Value.absent(),
    this.failedChecks = const Value.absent(),
  });
  IncidentsCompanion.insert({
    this.id = const Value.absent(),
    required int targetId,
    required String kind,
    required String title,
    required String description,
    required DateTime startedAt,
    this.endedAt = const Value.absent(),
    this.peak = const Value.absent(),
    this.failedChecks = const Value.absent(),
  }) : targetId = Value(targetId),
       kind = Value(kind),
       title = Value(title),
       description = Value(description),
       startedAt = Value(startedAt);
  static Insertable<Incident> custom({
    Expression<int>? id,
    Expression<int>? targetId,
    Expression<String>? kind,
    Expression<String>? title,
    Expression<String>? description,
    Expression<DateTime>? startedAt,
    Expression<DateTime>? endedAt,
    Expression<double>? peak,
    Expression<int>? failedChecks,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (targetId != null) 'target_id': targetId,
      if (kind != null) 'kind': kind,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (startedAt != null) 'started_at': startedAt,
      if (endedAt != null) 'ended_at': endedAt,
      if (peak != null) 'peak': peak,
      if (failedChecks != null) 'failed_checks': failedChecks,
    });
  }

  IncidentsCompanion copyWith({
    Value<int>? id,
    Value<int>? targetId,
    Value<String>? kind,
    Value<String>? title,
    Value<String>? description,
    Value<DateTime>? startedAt,
    Value<DateTime?>? endedAt,
    Value<double?>? peak,
    Value<int>? failedChecks,
  }) {
    return IncidentsCompanion(
      id: id ?? this.id,
      targetId: targetId ?? this.targetId,
      kind: kind ?? this.kind,
      title: title ?? this.title,
      description: description ?? this.description,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      peak: peak ?? this.peak,
      failedChecks: failedChecks ?? this.failedChecks,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (targetId.present) {
      map['target_id'] = Variable<int>(targetId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (endedAt.present) {
      map['ended_at'] = Variable<DateTime>(endedAt.value);
    }
    if (peak.present) {
      map['peak'] = Variable<double>(peak.value);
    }
    if (failedChecks.present) {
      map['failed_checks'] = Variable<int>(failedChecks.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('IncidentsCompanion(')
          ..write('id: $id, ')
          ..write('targetId: $targetId, ')
          ..write('kind: $kind, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('peak: $peak, ')
          ..write('failedChecks: $failedChecks')
          ..write(')'))
        .toString();
  }
}

class $AlertRulesTable extends AlertRules with TableInfo<$AlertRulesTable, AlertRule> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AlertRulesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _targetMeta = const VerificationMeta('target');
  @override
  late final GeneratedColumn<String> target = GeneratedColumn<String>(
    'target',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _metricMeta = const VerificationMeta('metric');
  @override
  late final GeneratedColumn<String> metric = GeneratedColumn<String>(
    'metric',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _thresholdMeta = const VerificationMeta('threshold');
  @override
  late final GeneratedColumn<double> threshold = GeneratedColumn<double>(
    'threshold',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _forSecondsMeta = const VerificationMeta('forSeconds');
  @override
  late final GeneratedColumn<int> forSeconds = GeneratedColumn<int>(
    'for_seconds',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(30),
  );
  static const VerificationMeta _channelsMeta = const VerificationMeta('channels');
  @override
  late final GeneratedColumn<int> channels = GeneratedColumn<int>(
    'channels',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _enabledMeta = const VerificationMeta('enabled');
  @override
  late final GeneratedColumn<bool> enabled = GeneratedColumn<bool>(
    'enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('CHECK ("enabled" IN (0, 1))'),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _breachSinceMeta = const VerificationMeta('breachSince');
  @override
  late final GeneratedColumn<DateTime> breachSince = GeneratedColumn<DateTime>(
    'breach_since',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _firingMeta = const VerificationMeta('firing');
  @override
  late final GeneratedColumn<bool> firing = GeneratedColumn<bool>(
    'firing',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('CHECK ("firing" IN (0, 1))'),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _lastFiredAtMeta = const VerificationMeta('lastFiredAt');
  @override
  late final GeneratedColumn<DateTime> lastFiredAt = GeneratedColumn<DateTime>(
    'last_fired_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    target,
    metric,
    threshold,
    forSeconds,
    channels,
    enabled,
    createdAt,
    breachSince,
    firing,
    lastFiredAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'alert_rules';
  @override
  VerificationContext validateIntegrity(Insertable<AlertRule> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('title')) {
      context.handle(_titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('target')) {
      context.handle(_targetMeta, target.isAcceptableOrUnknown(data['target']!, _targetMeta));
    } else if (isInserting) {
      context.missing(_targetMeta);
    }
    if (data.containsKey('metric')) {
      context.handle(_metricMeta, metric.isAcceptableOrUnknown(data['metric']!, _metricMeta));
    } else if (isInserting) {
      context.missing(_metricMeta);
    }
    if (data.containsKey('threshold')) {
      context.handle(_thresholdMeta, threshold.isAcceptableOrUnknown(data['threshold']!, _thresholdMeta));
    }
    if (data.containsKey('for_seconds')) {
      context.handle(_forSecondsMeta, forSeconds.isAcceptableOrUnknown(data['for_seconds']!, _forSecondsMeta));
    }
    if (data.containsKey('channels')) {
      context.handle(_channelsMeta, channels.isAcceptableOrUnknown(data['channels']!, _channelsMeta));
    }
    if (data.containsKey('enabled')) {
      context.handle(_enabledMeta, enabled.isAcceptableOrUnknown(data['enabled']!, _enabledMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta, createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('breach_since')) {
      context.handle(_breachSinceMeta, breachSince.isAcceptableOrUnknown(data['breach_since']!, _breachSinceMeta));
    }
    if (data.containsKey('firing')) {
      context.handle(_firingMeta, firing.isAcceptableOrUnknown(data['firing']!, _firingMeta));
    }
    if (data.containsKey('last_fired_at')) {
      context.handle(_lastFiredAtMeta, lastFiredAt.isAcceptableOrUnknown(data['last_fired_at']!, _lastFiredAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AlertRule map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AlertRule(
      id: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      title: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      target: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}target'])!,
      metric: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}metric'])!,
      threshold: attachedDatabase.typeMapping.read(DriftSqlType.double, data['${effectivePrefix}threshold'])!,
      forSeconds: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}for_seconds'])!,
      channels: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}channels'])!,
      enabled: attachedDatabase.typeMapping.read(DriftSqlType.bool, data['${effectivePrefix}enabled'])!,
      createdAt: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      breachSince: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}breach_since']),
      firing: attachedDatabase.typeMapping.read(DriftSqlType.bool, data['${effectivePrefix}firing'])!,
      lastFiredAt: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}last_fired_at']),
    );
  }

  @override
  $AlertRulesTable createAlias(String alias) {
    return $AlertRulesTable(attachedDatabase, alias);
  }
}

class AlertRule extends DataClass implements Insertable<AlertRule> {
  final int id;
  final String title;

  /// A host, or '*' for any monitored target.
  final String target;

  /// latency | loss | down | newDevice
  final String metric;
  final double threshold;
  final int forSeconds;

  /// Bitmask of [AlertChannel] values.
  final int channels;
  final bool enabled;
  final DateTime createdAt;

  /// When the condition first became true in the current breach, if any.
  final DateTime? breachSince;

  /// Set while the rule is firing; cleared when the condition recovers.
  final bool firing;
  final DateTime? lastFiredAt;
  const AlertRule({
    required this.id,
    required this.title,
    required this.target,
    required this.metric,
    required this.threshold,
    required this.forSeconds,
    required this.channels,
    required this.enabled,
    required this.createdAt,
    this.breachSince,
    required this.firing,
    this.lastFiredAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['title'] = Variable<String>(title);
    map['target'] = Variable<String>(target);
    map['metric'] = Variable<String>(metric);
    map['threshold'] = Variable<double>(threshold);
    map['for_seconds'] = Variable<int>(forSeconds);
    map['channels'] = Variable<int>(channels);
    map['enabled'] = Variable<bool>(enabled);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || breachSince != null) {
      map['breach_since'] = Variable<DateTime>(breachSince);
    }
    map['firing'] = Variable<bool>(firing);
    if (!nullToAbsent || lastFiredAt != null) {
      map['last_fired_at'] = Variable<DateTime>(lastFiredAt);
    }
    return map;
  }

  AlertRulesCompanion toCompanion(bool nullToAbsent) {
    return AlertRulesCompanion(
      id: Value(id),
      title: Value(title),
      target: Value(target),
      metric: Value(metric),
      threshold: Value(threshold),
      forSeconds: Value(forSeconds),
      channels: Value(channels),
      enabled: Value(enabled),
      createdAt: Value(createdAt),
      breachSince: breachSince == null && nullToAbsent ? const Value.absent() : Value(breachSince),
      firing: Value(firing),
      lastFiredAt: lastFiredAt == null && nullToAbsent ? const Value.absent() : Value(lastFiredAt),
    );
  }

  factory AlertRule.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AlertRule(
      id: serializer.fromJson<int>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      target: serializer.fromJson<String>(json['target']),
      metric: serializer.fromJson<String>(json['metric']),
      threshold: serializer.fromJson<double>(json['threshold']),
      forSeconds: serializer.fromJson<int>(json['forSeconds']),
      channels: serializer.fromJson<int>(json['channels']),
      enabled: serializer.fromJson<bool>(json['enabled']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      breachSince: serializer.fromJson<DateTime?>(json['breachSince']),
      firing: serializer.fromJson<bool>(json['firing']),
      lastFiredAt: serializer.fromJson<DateTime?>(json['lastFiredAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'title': serializer.toJson<String>(title),
      'target': serializer.toJson<String>(target),
      'metric': serializer.toJson<String>(metric),
      'threshold': serializer.toJson<double>(threshold),
      'forSeconds': serializer.toJson<int>(forSeconds),
      'channels': serializer.toJson<int>(channels),
      'enabled': serializer.toJson<bool>(enabled),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'breachSince': serializer.toJson<DateTime?>(breachSince),
      'firing': serializer.toJson<bool>(firing),
      'lastFiredAt': serializer.toJson<DateTime?>(lastFiredAt),
    };
  }

  AlertRule copyWith({
    int? id,
    String? title,
    String? target,
    String? metric,
    double? threshold,
    int? forSeconds,
    int? channels,
    bool? enabled,
    DateTime? createdAt,
    Value<DateTime?> breachSince = const Value.absent(),
    bool? firing,
    Value<DateTime?> lastFiredAt = const Value.absent(),
  }) => AlertRule(
    id: id ?? this.id,
    title: title ?? this.title,
    target: target ?? this.target,
    metric: metric ?? this.metric,
    threshold: threshold ?? this.threshold,
    forSeconds: forSeconds ?? this.forSeconds,
    channels: channels ?? this.channels,
    enabled: enabled ?? this.enabled,
    createdAt: createdAt ?? this.createdAt,
    breachSince: breachSince.present ? breachSince.value : this.breachSince,
    firing: firing ?? this.firing,
    lastFiredAt: lastFiredAt.present ? lastFiredAt.value : this.lastFiredAt,
  );
  AlertRule copyWithCompanion(AlertRulesCompanion data) {
    return AlertRule(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      target: data.target.present ? data.target.value : this.target,
      metric: data.metric.present ? data.metric.value : this.metric,
      threshold: data.threshold.present ? data.threshold.value : this.threshold,
      forSeconds: data.forSeconds.present ? data.forSeconds.value : this.forSeconds,
      channels: data.channels.present ? data.channels.value : this.channels,
      enabled: data.enabled.present ? data.enabled.value : this.enabled,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      breachSince: data.breachSince.present ? data.breachSince.value : this.breachSince,
      firing: data.firing.present ? data.firing.value : this.firing,
      lastFiredAt: data.lastFiredAt.present ? data.lastFiredAt.value : this.lastFiredAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AlertRule(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('target: $target, ')
          ..write('metric: $metric, ')
          ..write('threshold: $threshold, ')
          ..write('forSeconds: $forSeconds, ')
          ..write('channels: $channels, ')
          ..write('enabled: $enabled, ')
          ..write('createdAt: $createdAt, ')
          ..write('breachSince: $breachSince, ')
          ..write('firing: $firing, ')
          ..write('lastFiredAt: $lastFiredAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    target,
    metric,
    threshold,
    forSeconds,
    channels,
    enabled,
    createdAt,
    breachSince,
    firing,
    lastFiredAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AlertRule &&
          other.id == this.id &&
          other.title == this.title &&
          other.target == this.target &&
          other.metric == this.metric &&
          other.threshold == this.threshold &&
          other.forSeconds == this.forSeconds &&
          other.channels == this.channels &&
          other.enabled == this.enabled &&
          other.createdAt == this.createdAt &&
          other.breachSince == this.breachSince &&
          other.firing == this.firing &&
          other.lastFiredAt == this.lastFiredAt);
}

class AlertRulesCompanion extends UpdateCompanion<AlertRule> {
  final Value<int> id;
  final Value<String> title;
  final Value<String> target;
  final Value<String> metric;
  final Value<double> threshold;
  final Value<int> forSeconds;
  final Value<int> channels;
  final Value<bool> enabled;
  final Value<DateTime> createdAt;
  final Value<DateTime?> breachSince;
  final Value<bool> firing;
  final Value<DateTime?> lastFiredAt;
  const AlertRulesCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.target = const Value.absent(),
    this.metric = const Value.absent(),
    this.threshold = const Value.absent(),
    this.forSeconds = const Value.absent(),
    this.channels = const Value.absent(),
    this.enabled = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.breachSince = const Value.absent(),
    this.firing = const Value.absent(),
    this.lastFiredAt = const Value.absent(),
  });
  AlertRulesCompanion.insert({
    this.id = const Value.absent(),
    required String title,
    required String target,
    required String metric,
    this.threshold = const Value.absent(),
    this.forSeconds = const Value.absent(),
    this.channels = const Value.absent(),
    this.enabled = const Value.absent(),
    required DateTime createdAt,
    this.breachSince = const Value.absent(),
    this.firing = const Value.absent(),
    this.lastFiredAt = const Value.absent(),
  }) : title = Value(title),
       target = Value(target),
       metric = Value(metric),
       createdAt = Value(createdAt);
  static Insertable<AlertRule> custom({
    Expression<int>? id,
    Expression<String>? title,
    Expression<String>? target,
    Expression<String>? metric,
    Expression<double>? threshold,
    Expression<int>? forSeconds,
    Expression<int>? channels,
    Expression<bool>? enabled,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? breachSince,
    Expression<bool>? firing,
    Expression<DateTime>? lastFiredAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (target != null) 'target': target,
      if (metric != null) 'metric': metric,
      if (threshold != null) 'threshold': threshold,
      if (forSeconds != null) 'for_seconds': forSeconds,
      if (channels != null) 'channels': channels,
      if (enabled != null) 'enabled': enabled,
      if (createdAt != null) 'created_at': createdAt,
      if (breachSince != null) 'breach_since': breachSince,
      if (firing != null) 'firing': firing,
      if (lastFiredAt != null) 'last_fired_at': lastFiredAt,
    });
  }

  AlertRulesCompanion copyWith({
    Value<int>? id,
    Value<String>? title,
    Value<String>? target,
    Value<String>? metric,
    Value<double>? threshold,
    Value<int>? forSeconds,
    Value<int>? channels,
    Value<bool>? enabled,
    Value<DateTime>? createdAt,
    Value<DateTime?>? breachSince,
    Value<bool>? firing,
    Value<DateTime?>? lastFiredAt,
  }) {
    return AlertRulesCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      target: target ?? this.target,
      metric: metric ?? this.metric,
      threshold: threshold ?? this.threshold,
      forSeconds: forSeconds ?? this.forSeconds,
      channels: channels ?? this.channels,
      enabled: enabled ?? this.enabled,
      createdAt: createdAt ?? this.createdAt,
      breachSince: breachSince ?? this.breachSince,
      firing: firing ?? this.firing,
      lastFiredAt: lastFiredAt ?? this.lastFiredAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (target.present) {
      map['target'] = Variable<String>(target.value);
    }
    if (metric.present) {
      map['metric'] = Variable<String>(metric.value);
    }
    if (threshold.present) {
      map['threshold'] = Variable<double>(threshold.value);
    }
    if (forSeconds.present) {
      map['for_seconds'] = Variable<int>(forSeconds.value);
    }
    if (channels.present) {
      map['channels'] = Variable<int>(channels.value);
    }
    if (enabled.present) {
      map['enabled'] = Variable<bool>(enabled.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (breachSince.present) {
      map['breach_since'] = Variable<DateTime>(breachSince.value);
    }
    if (firing.present) {
      map['firing'] = Variable<bool>(firing.value);
    }
    if (lastFiredAt.present) {
      map['last_fired_at'] = Variable<DateTime>(lastFiredAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AlertRulesCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('target: $target, ')
          ..write('metric: $metric, ')
          ..write('threshold: $threshold, ')
          ..write('forSeconds: $forSeconds, ')
          ..write('channels: $channels, ')
          ..write('enabled: $enabled, ')
          ..write('createdAt: $createdAt, ')
          ..write('breachSince: $breachSince, ')
          ..write('firing: $firing, ')
          ..write('lastFiredAt: $lastFiredAt')
          ..write(')'))
        .toString();
  }
}

class $AlertEventsTable extends AlertEvents with TableInfo<$AlertEventsTable, AlertEvent> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AlertEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'),
  );
  static const VerificationMeta _ruleIdMeta = const VerificationMeta('ruleId');
  @override
  late final GeneratedColumn<int> ruleId = GeneratedColumn<int>(
    'rule_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('REFERENCES alert_rules (id) ON DELETE CASCADE'),
  );
  static const VerificationMeta _atMeta = const VerificationMeta('at');
  @override
  late final GeneratedColumn<DateTime> at = GeneratedColumn<DateTime>(
    'at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _messageMeta = const VerificationMeta('message');
  @override
  late final GeneratedColumn<String> message = GeneratedColumn<String>(
    'message',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<double> value = GeneratedColumn<double>(
    'value',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dismissedMeta = const VerificationMeta('dismissed');
  @override
  late final GeneratedColumn<bool> dismissed = GeneratedColumn<bool>(
    'dismissed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('CHECK ("dismissed" IN (0, 1))'),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [id, ruleId, at, message, value, dismissed];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'alert_events';
  @override
  VerificationContext validateIntegrity(Insertable<AlertEvent> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('rule_id')) {
      context.handle(_ruleIdMeta, ruleId.isAcceptableOrUnknown(data['rule_id']!, _ruleIdMeta));
    } else if (isInserting) {
      context.missing(_ruleIdMeta);
    }
    if (data.containsKey('at')) {
      context.handle(_atMeta, at.isAcceptableOrUnknown(data['at']!, _atMeta));
    } else if (isInserting) {
      context.missing(_atMeta);
    }
    if (data.containsKey('message')) {
      context.handle(_messageMeta, message.isAcceptableOrUnknown(data['message']!, _messageMeta));
    } else if (isInserting) {
      context.missing(_messageMeta);
    }
    if (data.containsKey('value')) {
      context.handle(_valueMeta, value.isAcceptableOrUnknown(data['value']!, _valueMeta));
    }
    if (data.containsKey('dismissed')) {
      context.handle(_dismissedMeta, dismissed.isAcceptableOrUnknown(data['dismissed']!, _dismissedMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AlertEvent map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AlertEvent(
      id: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      ruleId: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}rule_id'])!,
      at: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}at'])!,
      message: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}message'])!,
      value: attachedDatabase.typeMapping.read(DriftSqlType.double, data['${effectivePrefix}value']),
      dismissed: attachedDatabase.typeMapping.read(DriftSqlType.bool, data['${effectivePrefix}dismissed'])!,
    );
  }

  @override
  $AlertEventsTable createAlias(String alias) {
    return $AlertEventsTable(attachedDatabase, alias);
  }
}

class AlertEvent extends DataClass implements Insertable<AlertEvent> {
  final int id;
  final int ruleId;
  final DateTime at;
  final String message;
  final double? value;
  final bool dismissed;
  const AlertEvent({
    required this.id,
    required this.ruleId,
    required this.at,
    required this.message,
    this.value,
    required this.dismissed,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['rule_id'] = Variable<int>(ruleId);
    map['at'] = Variable<DateTime>(at);
    map['message'] = Variable<String>(message);
    if (!nullToAbsent || value != null) {
      map['value'] = Variable<double>(value);
    }
    map['dismissed'] = Variable<bool>(dismissed);
    return map;
  }

  AlertEventsCompanion toCompanion(bool nullToAbsent) {
    return AlertEventsCompanion(
      id: Value(id),
      ruleId: Value(ruleId),
      at: Value(at),
      message: Value(message),
      value: value == null && nullToAbsent ? const Value.absent() : Value(value),
      dismissed: Value(dismissed),
    );
  }

  factory AlertEvent.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AlertEvent(
      id: serializer.fromJson<int>(json['id']),
      ruleId: serializer.fromJson<int>(json['ruleId']),
      at: serializer.fromJson<DateTime>(json['at']),
      message: serializer.fromJson<String>(json['message']),
      value: serializer.fromJson<double?>(json['value']),
      dismissed: serializer.fromJson<bool>(json['dismissed']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'ruleId': serializer.toJson<int>(ruleId),
      'at': serializer.toJson<DateTime>(at),
      'message': serializer.toJson<String>(message),
      'value': serializer.toJson<double?>(value),
      'dismissed': serializer.toJson<bool>(dismissed),
    };
  }

  AlertEvent copyWith({
    int? id,
    int? ruleId,
    DateTime? at,
    String? message,
    Value<double?> value = const Value.absent(),
    bool? dismissed,
  }) => AlertEvent(
    id: id ?? this.id,
    ruleId: ruleId ?? this.ruleId,
    at: at ?? this.at,
    message: message ?? this.message,
    value: value.present ? value.value : this.value,
    dismissed: dismissed ?? this.dismissed,
  );
  AlertEvent copyWithCompanion(AlertEventsCompanion data) {
    return AlertEvent(
      id: data.id.present ? data.id.value : this.id,
      ruleId: data.ruleId.present ? data.ruleId.value : this.ruleId,
      at: data.at.present ? data.at.value : this.at,
      message: data.message.present ? data.message.value : this.message,
      value: data.value.present ? data.value.value : this.value,
      dismissed: data.dismissed.present ? data.dismissed.value : this.dismissed,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AlertEvent(')
          ..write('id: $id, ')
          ..write('ruleId: $ruleId, ')
          ..write('at: $at, ')
          ..write('message: $message, ')
          ..write('value: $value, ')
          ..write('dismissed: $dismissed')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, ruleId, at, message, value, dismissed);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AlertEvent &&
          other.id == this.id &&
          other.ruleId == this.ruleId &&
          other.at == this.at &&
          other.message == this.message &&
          other.value == this.value &&
          other.dismissed == this.dismissed);
}

class AlertEventsCompanion extends UpdateCompanion<AlertEvent> {
  final Value<int> id;
  final Value<int> ruleId;
  final Value<DateTime> at;
  final Value<String> message;
  final Value<double?> value;
  final Value<bool> dismissed;
  const AlertEventsCompanion({
    this.id = const Value.absent(),
    this.ruleId = const Value.absent(),
    this.at = const Value.absent(),
    this.message = const Value.absent(),
    this.value = const Value.absent(),
    this.dismissed = const Value.absent(),
  });
  AlertEventsCompanion.insert({
    this.id = const Value.absent(),
    required int ruleId,
    required DateTime at,
    required String message,
    this.value = const Value.absent(),
    this.dismissed = const Value.absent(),
  }) : ruleId = Value(ruleId),
       at = Value(at),
       message = Value(message);
  static Insertable<AlertEvent> custom({
    Expression<int>? id,
    Expression<int>? ruleId,
    Expression<DateTime>? at,
    Expression<String>? message,
    Expression<double>? value,
    Expression<bool>? dismissed,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (ruleId != null) 'rule_id': ruleId,
      if (at != null) 'at': at,
      if (message != null) 'message': message,
      if (value != null) 'value': value,
      if (dismissed != null) 'dismissed': dismissed,
    });
  }

  AlertEventsCompanion copyWith({
    Value<int>? id,
    Value<int>? ruleId,
    Value<DateTime>? at,
    Value<String>? message,
    Value<double?>? value,
    Value<bool>? dismissed,
  }) {
    return AlertEventsCompanion(
      id: id ?? this.id,
      ruleId: ruleId ?? this.ruleId,
      at: at ?? this.at,
      message: message ?? this.message,
      value: value ?? this.value,
      dismissed: dismissed ?? this.dismissed,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (ruleId.present) {
      map['rule_id'] = Variable<int>(ruleId.value);
    }
    if (at.present) {
      map['at'] = Variable<DateTime>(at.value);
    }
    if (message.present) {
      map['message'] = Variable<String>(message.value);
    }
    if (value.present) {
      map['value'] = Variable<double>(value.value);
    }
    if (dismissed.present) {
      map['dismissed'] = Variable<bool>(dismissed.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AlertEventsCompanion(')
          ..write('id: $id, ')
          ..write('ruleId: $ruleId, ')
          ..write('at: $at, ')
          ..write('message: $message, ')
          ..write('value: $value, ')
          ..write('dismissed: $dismissed')
          ..write(')'))
        .toString();
  }
}

class $LanDevicesTable extends LanDevices with TableInfo<$LanDevicesTable, LanDevice> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LanDevicesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ipMeta = const VerificationMeta('ip');
  @override
  late final GeneratedColumn<String> ip = GeneratedColumn<String>(
    'ip',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _macMeta = const VerificationMeta('mac');
  @override
  late final GeneratedColumn<String> mac = GeneratedColumn<String>(
    'mac',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _hostnameMeta = const VerificationMeta('hostname');
  @override
  late final GeneratedColumn<String> hostname = GeneratedColumn<String>(
    'hostname',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _vendorMeta = const VerificationMeta('vendor');
  @override
  late final GeneratedColumn<String> vendor = GeneratedColumn<String>(
    'vendor',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _subnetMeta = const VerificationMeta('subnet');
  @override
  late final GeneratedColumn<String> subnet = GeneratedColumn<String>(
    'subnet',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _firstSeenMeta = const VerificationMeta('firstSeen');
  @override
  late final GeneratedColumn<DateTime> firstSeen = GeneratedColumn<DateTime>(
    'first_seen',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastSeenMeta = const VerificationMeta('lastSeen');
  @override
  late final GeneratedColumn<DateTime> lastSeen = GeneratedColumn<DateTime>(
    'last_seen',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, ip, mac, hostname, vendor, subnet, firstSeen, lastSeen];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'lan_devices';
  @override
  VerificationContext validateIntegrity(Insertable<LanDevice> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(_keyMeta, key.isAcceptableOrUnknown(data['key']!, _keyMeta));
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('ip')) {
      context.handle(_ipMeta, ip.isAcceptableOrUnknown(data['ip']!, _ipMeta));
    } else if (isInserting) {
      context.missing(_ipMeta);
    }
    if (data.containsKey('mac')) {
      context.handle(_macMeta, mac.isAcceptableOrUnknown(data['mac']!, _macMeta));
    }
    if (data.containsKey('hostname')) {
      context.handle(_hostnameMeta, hostname.isAcceptableOrUnknown(data['hostname']!, _hostnameMeta));
    }
    if (data.containsKey('vendor')) {
      context.handle(_vendorMeta, vendor.isAcceptableOrUnknown(data['vendor']!, _vendorMeta));
    }
    if (data.containsKey('subnet')) {
      context.handle(_subnetMeta, subnet.isAcceptableOrUnknown(data['subnet']!, _subnetMeta));
    } else if (isInserting) {
      context.missing(_subnetMeta);
    }
    if (data.containsKey('first_seen')) {
      context.handle(_firstSeenMeta, firstSeen.isAcceptableOrUnknown(data['first_seen']!, _firstSeenMeta));
    } else if (isInserting) {
      context.missing(_firstSeenMeta);
    }
    if (data.containsKey('last_seen')) {
      context.handle(_lastSeenMeta, lastSeen.isAcceptableOrUnknown(data['last_seen']!, _lastSeenMeta));
    } else if (isInserting) {
      context.missing(_lastSeenMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  LanDevice map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LanDevice(
      key: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}key'])!,
      ip: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}ip'])!,
      mac: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}mac']),
      hostname: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}hostname']),
      vendor: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}vendor']),
      subnet: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}subnet'])!,
      firstSeen: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}first_seen'])!,
      lastSeen: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}last_seen'])!,
    );
  }

  @override
  $LanDevicesTable createAlias(String alias) {
    return $LanDevicesTable(attachedDatabase, alias);
  }
}

class LanDevice extends DataClass implements Insertable<LanDevice> {
  final String key;
  final String ip;
  final String? mac;
  final String? hostname;
  final String? vendor;
  final String subnet;
  final DateTime firstSeen;
  final DateTime lastSeen;
  const LanDevice({
    required this.key,
    required this.ip,
    this.mac,
    this.hostname,
    this.vendor,
    required this.subnet,
    required this.firstSeen,
    required this.lastSeen,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['ip'] = Variable<String>(ip);
    if (!nullToAbsent || mac != null) {
      map['mac'] = Variable<String>(mac);
    }
    if (!nullToAbsent || hostname != null) {
      map['hostname'] = Variable<String>(hostname);
    }
    if (!nullToAbsent || vendor != null) {
      map['vendor'] = Variable<String>(vendor);
    }
    map['subnet'] = Variable<String>(subnet);
    map['first_seen'] = Variable<DateTime>(firstSeen);
    map['last_seen'] = Variable<DateTime>(lastSeen);
    return map;
  }

  LanDevicesCompanion toCompanion(bool nullToAbsent) {
    return LanDevicesCompanion(
      key: Value(key),
      ip: Value(ip),
      mac: mac == null && nullToAbsent ? const Value.absent() : Value(mac),
      hostname: hostname == null && nullToAbsent ? const Value.absent() : Value(hostname),
      vendor: vendor == null && nullToAbsent ? const Value.absent() : Value(vendor),
      subnet: Value(subnet),
      firstSeen: Value(firstSeen),
      lastSeen: Value(lastSeen),
    );
  }

  factory LanDevice.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LanDevice(
      key: serializer.fromJson<String>(json['key']),
      ip: serializer.fromJson<String>(json['ip']),
      mac: serializer.fromJson<String?>(json['mac']),
      hostname: serializer.fromJson<String?>(json['hostname']),
      vendor: serializer.fromJson<String?>(json['vendor']),
      subnet: serializer.fromJson<String>(json['subnet']),
      firstSeen: serializer.fromJson<DateTime>(json['firstSeen']),
      lastSeen: serializer.fromJson<DateTime>(json['lastSeen']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'ip': serializer.toJson<String>(ip),
      'mac': serializer.toJson<String?>(mac),
      'hostname': serializer.toJson<String?>(hostname),
      'vendor': serializer.toJson<String?>(vendor),
      'subnet': serializer.toJson<String>(subnet),
      'firstSeen': serializer.toJson<DateTime>(firstSeen),
      'lastSeen': serializer.toJson<DateTime>(lastSeen),
    };
  }

  LanDevice copyWith({
    String? key,
    String? ip,
    Value<String?> mac = const Value.absent(),
    Value<String?> hostname = const Value.absent(),
    Value<String?> vendor = const Value.absent(),
    String? subnet,
    DateTime? firstSeen,
    DateTime? lastSeen,
  }) => LanDevice(
    key: key ?? this.key,
    ip: ip ?? this.ip,
    mac: mac.present ? mac.value : this.mac,
    hostname: hostname.present ? hostname.value : this.hostname,
    vendor: vendor.present ? vendor.value : this.vendor,
    subnet: subnet ?? this.subnet,
    firstSeen: firstSeen ?? this.firstSeen,
    lastSeen: lastSeen ?? this.lastSeen,
  );
  LanDevice copyWithCompanion(LanDevicesCompanion data) {
    return LanDevice(
      key: data.key.present ? data.key.value : this.key,
      ip: data.ip.present ? data.ip.value : this.ip,
      mac: data.mac.present ? data.mac.value : this.mac,
      hostname: data.hostname.present ? data.hostname.value : this.hostname,
      vendor: data.vendor.present ? data.vendor.value : this.vendor,
      subnet: data.subnet.present ? data.subnet.value : this.subnet,
      firstSeen: data.firstSeen.present ? data.firstSeen.value : this.firstSeen,
      lastSeen: data.lastSeen.present ? data.lastSeen.value : this.lastSeen,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LanDevice(')
          ..write('key: $key, ')
          ..write('ip: $ip, ')
          ..write('mac: $mac, ')
          ..write('hostname: $hostname, ')
          ..write('vendor: $vendor, ')
          ..write('subnet: $subnet, ')
          ..write('firstSeen: $firstSeen, ')
          ..write('lastSeen: $lastSeen')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, ip, mac, hostname, vendor, subnet, firstSeen, lastSeen);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LanDevice &&
          other.key == this.key &&
          other.ip == this.ip &&
          other.mac == this.mac &&
          other.hostname == this.hostname &&
          other.vendor == this.vendor &&
          other.subnet == this.subnet &&
          other.firstSeen == this.firstSeen &&
          other.lastSeen == this.lastSeen);
}

class LanDevicesCompanion extends UpdateCompanion<LanDevice> {
  final Value<String> key;
  final Value<String> ip;
  final Value<String?> mac;
  final Value<String?> hostname;
  final Value<String?> vendor;
  final Value<String> subnet;
  final Value<DateTime> firstSeen;
  final Value<DateTime> lastSeen;
  final Value<int> rowid;
  const LanDevicesCompanion({
    this.key = const Value.absent(),
    this.ip = const Value.absent(),
    this.mac = const Value.absent(),
    this.hostname = const Value.absent(),
    this.vendor = const Value.absent(),
    this.subnet = const Value.absent(),
    this.firstSeen = const Value.absent(),
    this.lastSeen = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LanDevicesCompanion.insert({
    required String key,
    required String ip,
    this.mac = const Value.absent(),
    this.hostname = const Value.absent(),
    this.vendor = const Value.absent(),
    required String subnet,
    required DateTime firstSeen,
    required DateTime lastSeen,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       ip = Value(ip),
       subnet = Value(subnet),
       firstSeen = Value(firstSeen),
       lastSeen = Value(lastSeen);
  static Insertable<LanDevice> custom({
    Expression<String>? key,
    Expression<String>? ip,
    Expression<String>? mac,
    Expression<String>? hostname,
    Expression<String>? vendor,
    Expression<String>? subnet,
    Expression<DateTime>? firstSeen,
    Expression<DateTime>? lastSeen,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (ip != null) 'ip': ip,
      if (mac != null) 'mac': mac,
      if (hostname != null) 'hostname': hostname,
      if (vendor != null) 'vendor': vendor,
      if (subnet != null) 'subnet': subnet,
      if (firstSeen != null) 'first_seen': firstSeen,
      if (lastSeen != null) 'last_seen': lastSeen,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LanDevicesCompanion copyWith({
    Value<String>? key,
    Value<String>? ip,
    Value<String?>? mac,
    Value<String?>? hostname,
    Value<String?>? vendor,
    Value<String>? subnet,
    Value<DateTime>? firstSeen,
    Value<DateTime>? lastSeen,
    Value<int>? rowid,
  }) {
    return LanDevicesCompanion(
      key: key ?? this.key,
      ip: ip ?? this.ip,
      mac: mac ?? this.mac,
      hostname: hostname ?? this.hostname,
      vendor: vendor ?? this.vendor,
      subnet: subnet ?? this.subnet,
      firstSeen: firstSeen ?? this.firstSeen,
      lastSeen: lastSeen ?? this.lastSeen,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (ip.present) {
      map['ip'] = Variable<String>(ip.value);
    }
    if (mac.present) {
      map['mac'] = Variable<String>(mac.value);
    }
    if (hostname.present) {
      map['hostname'] = Variable<String>(hostname.value);
    }
    if (vendor.present) {
      map['vendor'] = Variable<String>(vendor.value);
    }
    if (subnet.present) {
      map['subnet'] = Variable<String>(subnet.value);
    }
    if (firstSeen.present) {
      map['first_seen'] = Variable<DateTime>(firstSeen.value);
    }
    if (lastSeen.present) {
      map['last_seen'] = Variable<DateTime>(lastSeen.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LanDevicesCompanion(')
          ..write('key: $key, ')
          ..write('ip: $ip, ')
          ..write('mac: $mac, ')
          ..write('hostname: $hostname, ')
          ..write('vendor: $vendor, ')
          ..write('subnet: $subnet, ')
          ..write('firstSeen: $firstSeen, ')
          ..write('lastSeen: $lastSeen, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $SessionsTable sessions = $SessionsTable(this);
  late final $SavedTargetsTable savedTargets = $SavedTargetsTable(this);
  late final $MonitorTargetsTable monitorTargets = $MonitorTargetsTable(this);
  late final $MonitorChecksTable monitorChecks = $MonitorChecksTable(this);
  late final $IncidentsTable incidents = $IncidentsTable(this);
  late final $AlertRulesTable alertRules = $AlertRulesTable(this);
  late final $AlertEventsTable alertEvents = $AlertEventsTable(this);
  late final $LanDevicesTable lanDevices = $LanDevicesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables => allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    sessions,
    savedTargets,
    monitorTargets,
    monitorChecks,
    incidents,
    alertRules,
    alertEvents,
    lanDevices,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName('monitor_targets', limitUpdateKind: UpdateKind.delete),
      result: [TableUpdate('monitor_checks', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName('monitor_targets', limitUpdateKind: UpdateKind.delete),
      result: [TableUpdate('incidents', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName('alert_rules', limitUpdateKind: UpdateKind.delete),
      result: [TableUpdate('alert_events', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$SessionsTableCreateCompanionBuilder =
    SessionsCompanion Function({
      Value<int> id,
      required String tool,
      required String target,
      Value<String?> label,
      required DateTime startedAt,
      required DateTime endedAt,
      Value<double?> avgMs,
      Value<double?> lossPct,
      Value<String> summary,
      Value<String> trend,
      Value<String> payload,
    });
typedef $$SessionsTableUpdateCompanionBuilder =
    SessionsCompanion Function({
      Value<int> id,
      Value<String> tool,
      Value<String> target,
      Value<String?> label,
      Value<DateTime> startedAt,
      Value<DateTime> endedAt,
      Value<double?> avgMs,
      Value<double?> lossPct,
      Value<String> summary,
      Value<String> trend,
      Value<String> payload,
    });

class $$SessionsTableFilterComposer extends Composer<_$AppDatabase, $SessionsTable> {
  $$SessionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get tool => $composableBuilder(column: $table.tool, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get target =>
      $composableBuilder(column: $table.target, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get endedAt =>
      $composableBuilder(column: $table.endedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get avgMs =>
      $composableBuilder(column: $table.avgMs, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get lossPct =>
      $composableBuilder(column: $table.lossPct, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get summary =>
      $composableBuilder(column: $table.summary, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get trend =>
      $composableBuilder(column: $table.trend, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => ColumnFilters(column));
}

class $$SessionsTableOrderingComposer extends Composer<_$AppDatabase, $SessionsTable> {
  $$SessionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get tool =>
      $composableBuilder(column: $table.tool, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get target =>
      $composableBuilder(column: $table.target, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get endedAt =>
      $composableBuilder(column: $table.endedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get avgMs =>
      $composableBuilder(column: $table.avgMs, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get lossPct =>
      $composableBuilder(column: $table.lossPct, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get summary =>
      $composableBuilder(column: $table.summary, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get trend =>
      $composableBuilder(column: $table.trend, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => ColumnOrderings(column));
}

class $$SessionsTableAnnotationComposer extends Composer<_$AppDatabase, $SessionsTable> {
  $$SessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id => $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get tool => $composableBuilder(column: $table.tool, builder: (column) => column);

  GeneratedColumn<String> get target => $composableBuilder(column: $table.target, builder: (column) => column);

  GeneratedColumn<String> get label => $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<DateTime> get startedAt => $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get endedAt => $composableBuilder(column: $table.endedAt, builder: (column) => column);

  GeneratedColumn<double> get avgMs => $composableBuilder(column: $table.avgMs, builder: (column) => column);

  GeneratedColumn<double> get lossPct => $composableBuilder(column: $table.lossPct, builder: (column) => column);

  GeneratedColumn<String> get summary => $composableBuilder(column: $table.summary, builder: (column) => column);

  GeneratedColumn<String> get trend => $composableBuilder(column: $table.trend, builder: (column) => column);

  GeneratedColumn<String> get payload => $composableBuilder(column: $table.payload, builder: (column) => column);
}

class $$SessionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SessionsTable,
          Session,
          $$SessionsTableFilterComposer,
          $$SessionsTableOrderingComposer,
          $$SessionsTableAnnotationComposer,
          $$SessionsTableCreateCompanionBuilder,
          $$SessionsTableUpdateCompanionBuilder,
          (Session, BaseReferences<_$AppDatabase, $SessionsTable, Session>),
          Session,
          PrefetchHooks Function()
        > {
  $$SessionsTableTableManager(_$AppDatabase db, $SessionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$SessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$SessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$SessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> tool = const Value.absent(),
                Value<String> target = const Value.absent(),
                Value<String?> label = const Value.absent(),
                Value<DateTime> startedAt = const Value.absent(),
                Value<DateTime> endedAt = const Value.absent(),
                Value<double?> avgMs = const Value.absent(),
                Value<double?> lossPct = const Value.absent(),
                Value<String> summary = const Value.absent(),
                Value<String> trend = const Value.absent(),
                Value<String> payload = const Value.absent(),
              }) => SessionsCompanion(
                id: id,
                tool: tool,
                target: target,
                label: label,
                startedAt: startedAt,
                endedAt: endedAt,
                avgMs: avgMs,
                lossPct: lossPct,
                summary: summary,
                trend: trend,
                payload: payload,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String tool,
                required String target,
                Value<String?> label = const Value.absent(),
                required DateTime startedAt,
                required DateTime endedAt,
                Value<double?> avgMs = const Value.absent(),
                Value<double?> lossPct = const Value.absent(),
                Value<String> summary = const Value.absent(),
                Value<String> trend = const Value.absent(),
                Value<String> payload = const Value.absent(),
              }) => SessionsCompanion.insert(
                id: id,
                tool: tool,
                target: target,
                label: label,
                startedAt: startedAt,
                endedAt: endedAt,
                avgMs: avgMs,
                lossPct: lossPct,
                summary: summary,
                trend: trend,
                payload: payload,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SessionsTable, Session>(table),
                  BaseReferences<_$AppDatabase, $SessionsTable, Session>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SessionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SessionsTable,
      Session,
      $$SessionsTableFilterComposer,
      $$SessionsTableOrderingComposer,
      $$SessionsTableAnnotationComposer,
      $$SessionsTableCreateCompanionBuilder,
      $$SessionsTableUpdateCompanionBuilder,
      (Session, BaseReferences<_$AppDatabase, $SessionsTable, Session>),
      Session,
      PrefetchHooks Function()
    >;
typedef $$SavedTargetsTableCreateCompanionBuilder =
    SavedTargetsCompanion Function({
      Value<int> id,
      required String name,
      required String host,
      Value<int> sortOrder,
      required DateTime createdAt,
      Value<DateTime?> lastUsedAt,
    });
typedef $$SavedTargetsTableUpdateCompanionBuilder =
    SavedTargetsCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String> host,
      Value<int> sortOrder,
      Value<DateTime> createdAt,
      Value<DateTime?> lastUsedAt,
    });

class $$SavedTargetsTableFilterComposer extends Composer<_$AppDatabase, $SavedTargetsTable> {
  $$SavedTargetsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get host => $composableBuilder(column: $table.host, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastUsedAt =>
      $composableBuilder(column: $table.lastUsedAt, builder: (column) => ColumnFilters(column));
}

class $$SavedTargetsTableOrderingComposer extends Composer<_$AppDatabase, $SavedTargetsTable> {
  $$SavedTargetsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get host =>
      $composableBuilder(column: $table.host, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastUsedAt =>
      $composableBuilder(column: $table.lastUsedAt, builder: (column) => ColumnOrderings(column));
}

class $$SavedTargetsTableAnnotationComposer extends Composer<_$AppDatabase, $SavedTargetsTable> {
  $$SavedTargetsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id => $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name => $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get host => $composableBuilder(column: $table.host, builder: (column) => column);

  GeneratedColumn<int> get sortOrder => $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt => $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get lastUsedAt =>
      $composableBuilder(column: $table.lastUsedAt, builder: (column) => column);
}

class $$SavedTargetsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SavedTargetsTable,
          SavedTarget,
          $$SavedTargetsTableFilterComposer,
          $$SavedTargetsTableOrderingComposer,
          $$SavedTargetsTableAnnotationComposer,
          $$SavedTargetsTableCreateCompanionBuilder,
          $$SavedTargetsTableUpdateCompanionBuilder,
          (SavedTarget, BaseReferences<_$AppDatabase, $SavedTargetsTable, SavedTarget>),
          SavedTarget,
          PrefetchHooks Function()
        > {
  $$SavedTargetsTableTableManager(_$AppDatabase db, $SavedTargetsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$SavedTargetsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$SavedTargetsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$SavedTargetsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> host = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> lastUsedAt = const Value.absent(),
              }) => SavedTargetsCompanion(
                id: id,
                name: name,
                host: host,
                sortOrder: sortOrder,
                createdAt: createdAt,
                lastUsedAt: lastUsedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required String host,
                Value<int> sortOrder = const Value.absent(),
                required DateTime createdAt,
                Value<DateTime?> lastUsedAt = const Value.absent(),
              }) => SavedTargetsCompanion.insert(
                id: id,
                name: name,
                host: host,
                sortOrder: sortOrder,
                createdAt: createdAt,
                lastUsedAt: lastUsedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SavedTargetsTable, SavedTarget>(table),
                  BaseReferences<_$AppDatabase, $SavedTargetsTable, SavedTarget>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SavedTargetsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SavedTargetsTable,
      SavedTarget,
      $$SavedTargetsTableFilterComposer,
      $$SavedTargetsTableOrderingComposer,
      $$SavedTargetsTableAnnotationComposer,
      $$SavedTargetsTableCreateCompanionBuilder,
      $$SavedTargetsTableUpdateCompanionBuilder,
      (SavedTarget, BaseReferences<_$AppDatabase, $SavedTargetsTable, SavedTarget>),
      SavedTarget,
      PrefetchHooks Function()
    >;
typedef $$MonitorTargetsTableCreateCompanionBuilder =
    MonitorTargetsCompanion Function({
      Value<int> id,
      required String host,
      required String name,
      Value<bool> enabled,
      Value<int> sortOrder,
      required DateTime createdAt,
    });
typedef $$MonitorTargetsTableUpdateCompanionBuilder =
    MonitorTargetsCompanion Function({
      Value<int> id,
      Value<String> host,
      Value<String> name,
      Value<bool> enabled,
      Value<int> sortOrder,
      Value<DateTime> createdAt,
    });

final class $$MonitorTargetsTableReferences extends BaseReferences<_$AppDatabase, $MonitorTargetsTable, MonitorTarget> {
  $$MonitorTargetsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$MonitorChecksTable, List<MonitorCheck>> _monitorChecksRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(db.monitorChecks, aliasName: 'monitor_targets__id__monitor_checks__target_id');

  $$MonitorChecksTableProcessedTableManager get monitorChecksRefs {
    final manager = $$MonitorChecksTableTableManager(
      $_db,
      $_db.monitorChecks,
    ).filter((f) => f.targetId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_monitorChecksRefsTable($_db));
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$IncidentsTable, List<Incident>> _incidentsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(db.incidents, aliasName: 'monitor_targets__id__incidents__target_id');

  $$IncidentsTableProcessedTableManager get incidentsRefs {
    final manager = $$IncidentsTableTableManager(
      $_db,
      $_db.incidents,
    ).filter((f) => f.targetId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_incidentsRefsTable($_db));
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$MonitorTargetsTableFilterComposer extends Composer<_$AppDatabase, $MonitorTargetsTable> {
  $$MonitorTargetsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get host => $composableBuilder(column: $table.host, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get enabled =>
      $composableBuilder(column: $table.enabled, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => ColumnFilters(column));

  Expression<bool> monitorChecksRefs(Expression<bool> Function($$MonitorChecksTableFilterComposer f) f) {
    final $$MonitorChecksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.monitorChecks,
      getReferencedColumn: (t) => t.targetId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$MonitorChecksTableFilterComposer(
            $db: $db,
            $table: $db.monitorChecks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> incidentsRefs(Expression<bool> Function($$IncidentsTableFilterComposer f) f) {
    final $$IncidentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.incidents,
      getReferencedColumn: (t) => t.targetId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$IncidentsTableFilterComposer(
            $db: $db,
            $table: $db.incidents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$MonitorTargetsTableOrderingComposer extends Composer<_$AppDatabase, $MonitorTargetsTable> {
  $$MonitorTargetsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get host =>
      $composableBuilder(column: $table.host, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get enabled =>
      $composableBuilder(column: $table.enabled, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$MonitorTargetsTableAnnotationComposer extends Composer<_$AppDatabase, $MonitorTargetsTable> {
  $$MonitorTargetsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id => $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get host => $composableBuilder(column: $table.host, builder: (column) => column);

  GeneratedColumn<String> get name => $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<bool> get enabled => $composableBuilder(column: $table.enabled, builder: (column) => column);

  GeneratedColumn<int> get sortOrder => $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt => $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> monitorChecksRefs<T extends Object>(
    Expression<T> Function($$MonitorChecksTableAnnotationComposer a) f,
  ) {
    final $$MonitorChecksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.monitorChecks,
      getReferencedColumn: (t) => t.targetId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$MonitorChecksTableAnnotationComposer(
            $db: $db,
            $table: $db.monitorChecks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> incidentsRefs<T extends Object>(Expression<T> Function($$IncidentsTableAnnotationComposer a) f) {
    final $$IncidentsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.incidents,
      getReferencedColumn: (t) => t.targetId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$IncidentsTableAnnotationComposer(
            $db: $db,
            $table: $db.incidents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$MonitorTargetsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MonitorTargetsTable,
          MonitorTarget,
          $$MonitorTargetsTableFilterComposer,
          $$MonitorTargetsTableOrderingComposer,
          $$MonitorTargetsTableAnnotationComposer,
          $$MonitorTargetsTableCreateCompanionBuilder,
          $$MonitorTargetsTableUpdateCompanionBuilder,
          (MonitorTarget, $$MonitorTargetsTableReferences),
          MonitorTarget,
          PrefetchHooks Function({bool monitorChecksRefs, bool incidentsRefs})
        > {
  $$MonitorTargetsTableTableManager(_$AppDatabase db, $MonitorTargetsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$MonitorTargetsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$MonitorTargetsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$MonitorTargetsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> host = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => MonitorTargetsCompanion(
                id: id,
                host: host,
                name: name,
                enabled: enabled,
                sortOrder: sortOrder,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String host,
                required String name,
                Value<bool> enabled = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                required DateTime createdAt,
              }) => MonitorTargetsCompanion.insert(
                id: id,
                host: host,
                name: name,
                enabled: enabled,
                sortOrder: sortOrder,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$MonitorTargetsTable, MonitorTarget>(table),
                  $$MonitorTargetsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({monitorChecksRefs = false, incidentsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (monitorChecksRefs) db.monitorChecks, if (incidentsRefs) db.incidents],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (monitorChecksRefs)
                    await $_getPrefetchedData<MonitorTarget, $MonitorTargetsTable, MonitorCheck>(
                      currentTable: table,
                      referencedTable: $$MonitorTargetsTableReferences._monitorChecksRefsTable(db),
                      managerFromTypedResult: (p0) => $$MonitorTargetsTableReferences(db, table, p0).monitorChecksRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.targetId == item.id),
                      typedResults: items,
                    ),
                  if (incidentsRefs)
                    await $_getPrefetchedData<MonitorTarget, $MonitorTargetsTable, Incident>(
                      currentTable: table,
                      referencedTable: $$MonitorTargetsTableReferences._incidentsRefsTable(db),
                      managerFromTypedResult: (p0) => $$MonitorTargetsTableReferences(db, table, p0).incidentsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.targetId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$MonitorTargetsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MonitorTargetsTable,
      MonitorTarget,
      $$MonitorTargetsTableFilterComposer,
      $$MonitorTargetsTableOrderingComposer,
      $$MonitorTargetsTableAnnotationComposer,
      $$MonitorTargetsTableCreateCompanionBuilder,
      $$MonitorTargetsTableUpdateCompanionBuilder,
      (MonitorTarget, $$MonitorTargetsTableReferences),
      MonitorTarget,
      PrefetchHooks Function({bool monitorChecksRefs, bool incidentsRefs})
    >;
typedef $$MonitorChecksTableCreateCompanionBuilder =
    MonitorChecksCompanion Function({
      Value<int> id,
      required int targetId,
      required DateTime at,
      required int sent,
      required int received,
      Value<double?> rttAvg,
      Value<double?> rttMax,
    });
typedef $$MonitorChecksTableUpdateCompanionBuilder =
    MonitorChecksCompanion Function({
      Value<int> id,
      Value<int> targetId,
      Value<DateTime> at,
      Value<int> sent,
      Value<int> received,
      Value<double?> rttAvg,
      Value<double?> rttMax,
    });

final class $$MonitorChecksTableReferences extends BaseReferences<_$AppDatabase, $MonitorChecksTable, MonitorCheck> {
  $$MonitorChecksTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $MonitorTargetsTable _targetIdTable(_$AppDatabase db) =>
      db.monitorTargets.createAlias('monitor_checks__target_id__monitor_targets__id');

  $$MonitorTargetsTableProcessedTableManager get targetId {
    final $_column = $_itemColumn<int>('target_id')!;

    final manager = $$MonitorTargetsTableTableManager(
      $_db,
      $_db.monitorTargets,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_targetIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$MonitorChecksTableFilterComposer extends Composer<_$AppDatabase, $MonitorChecksTable> {
  $$MonitorChecksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get at => $composableBuilder(column: $table.at, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get sent => $composableBuilder(column: $table.sent, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get received =>
      $composableBuilder(column: $table.received, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get rttAvg =>
      $composableBuilder(column: $table.rttAvg, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get rttMax =>
      $composableBuilder(column: $table.rttMax, builder: (column) => ColumnFilters(column));

  $$MonitorTargetsTableFilterComposer get targetId {
    final $$MonitorTargetsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.targetId,
      referencedTable: $db.monitorTargets,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$MonitorTargetsTableFilterComposer(
            $db: $db,
            $table: $db.monitorTargets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MonitorChecksTableOrderingComposer extends Composer<_$AppDatabase, $MonitorChecksTable> {
  $$MonitorChecksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get at =>
      $composableBuilder(column: $table.at, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get sent =>
      $composableBuilder(column: $table.sent, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get received =>
      $composableBuilder(column: $table.received, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get rttAvg =>
      $composableBuilder(column: $table.rttAvg, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get rttMax =>
      $composableBuilder(column: $table.rttMax, builder: (column) => ColumnOrderings(column));

  $$MonitorTargetsTableOrderingComposer get targetId {
    final $$MonitorTargetsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.targetId,
      referencedTable: $db.monitorTargets,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$MonitorTargetsTableOrderingComposer(
            $db: $db,
            $table: $db.monitorTargets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MonitorChecksTableAnnotationComposer extends Composer<_$AppDatabase, $MonitorChecksTable> {
  $$MonitorChecksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id => $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get at => $composableBuilder(column: $table.at, builder: (column) => column);

  GeneratedColumn<int> get sent => $composableBuilder(column: $table.sent, builder: (column) => column);

  GeneratedColumn<int> get received => $composableBuilder(column: $table.received, builder: (column) => column);

  GeneratedColumn<double> get rttAvg => $composableBuilder(column: $table.rttAvg, builder: (column) => column);

  GeneratedColumn<double> get rttMax => $composableBuilder(column: $table.rttMax, builder: (column) => column);

  $$MonitorTargetsTableAnnotationComposer get targetId {
    final $$MonitorTargetsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.targetId,
      referencedTable: $db.monitorTargets,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$MonitorTargetsTableAnnotationComposer(
            $db: $db,
            $table: $db.monitorTargets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MonitorChecksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MonitorChecksTable,
          MonitorCheck,
          $$MonitorChecksTableFilterComposer,
          $$MonitorChecksTableOrderingComposer,
          $$MonitorChecksTableAnnotationComposer,
          $$MonitorChecksTableCreateCompanionBuilder,
          $$MonitorChecksTableUpdateCompanionBuilder,
          (MonitorCheck, $$MonitorChecksTableReferences),
          MonitorCheck,
          PrefetchHooks Function({bool targetId})
        > {
  $$MonitorChecksTableTableManager(_$AppDatabase db, $MonitorChecksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$MonitorChecksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$MonitorChecksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$MonitorChecksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> targetId = const Value.absent(),
                Value<DateTime> at = const Value.absent(),
                Value<int> sent = const Value.absent(),
                Value<int> received = const Value.absent(),
                Value<double?> rttAvg = const Value.absent(),
                Value<double?> rttMax = const Value.absent(),
              }) => MonitorChecksCompanion(
                id: id,
                targetId: targetId,
                at: at,
                sent: sent,
                received: received,
                rttAvg: rttAvg,
                rttMax: rttMax,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int targetId,
                required DateTime at,
                required int sent,
                required int received,
                Value<double?> rttAvg = const Value.absent(),
                Value<double?> rttMax = const Value.absent(),
              }) => MonitorChecksCompanion.insert(
                id: id,
                targetId: targetId,
                at: at,
                sent: sent,
                received: received,
                rttAvg: rttAvg,
                rttMax: rttMax,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$MonitorChecksTable, MonitorCheck>(table),
                  $$MonitorChecksTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({targetId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (targetId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.targetId,
                                referencedTable: $$MonitorChecksTableReferences._targetIdTable(db),
                                referencedColumn: $$MonitorChecksTableReferences._targetIdTable(db).id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$MonitorChecksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MonitorChecksTable,
      MonitorCheck,
      $$MonitorChecksTableFilterComposer,
      $$MonitorChecksTableOrderingComposer,
      $$MonitorChecksTableAnnotationComposer,
      $$MonitorChecksTableCreateCompanionBuilder,
      $$MonitorChecksTableUpdateCompanionBuilder,
      (MonitorCheck, $$MonitorChecksTableReferences),
      MonitorCheck,
      PrefetchHooks Function({bool targetId})
    >;
typedef $$IncidentsTableCreateCompanionBuilder =
    IncidentsCompanion Function({
      Value<int> id,
      required int targetId,
      required String kind,
      required String title,
      required String description,
      required DateTime startedAt,
      Value<DateTime?> endedAt,
      Value<double?> peak,
      Value<int> failedChecks,
    });
typedef $$IncidentsTableUpdateCompanionBuilder =
    IncidentsCompanion Function({
      Value<int> id,
      Value<int> targetId,
      Value<String> kind,
      Value<String> title,
      Value<String> description,
      Value<DateTime> startedAt,
      Value<DateTime?> endedAt,
      Value<double?> peak,
      Value<int> failedChecks,
    });

final class $$IncidentsTableReferences extends BaseReferences<_$AppDatabase, $IncidentsTable, Incident> {
  $$IncidentsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $MonitorTargetsTable _targetIdTable(_$AppDatabase db) =>
      db.monitorTargets.createAlias('incidents__target_id__monitor_targets__id');

  $$MonitorTargetsTableProcessedTableManager get targetId {
    final $_column = $_itemColumn<int>('target_id')!;

    final manager = $$MonitorTargetsTableTableManager(
      $_db,
      $_db.monitorTargets,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_targetIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$IncidentsTableFilterComposer extends Composer<_$AppDatabase, $IncidentsTable> {
  $$IncidentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get kind => $composableBuilder(column: $table.kind, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get description =>
      $composableBuilder(column: $table.description, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get endedAt =>
      $composableBuilder(column: $table.endedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get peak => $composableBuilder(column: $table.peak, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get failedChecks =>
      $composableBuilder(column: $table.failedChecks, builder: (column) => ColumnFilters(column));

  $$MonitorTargetsTableFilterComposer get targetId {
    final $$MonitorTargetsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.targetId,
      referencedTable: $db.monitorTargets,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$MonitorTargetsTableFilterComposer(
            $db: $db,
            $table: $db.monitorTargets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$IncidentsTableOrderingComposer extends Composer<_$AppDatabase, $IncidentsTable> {
  $$IncidentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get description =>
      $composableBuilder(column: $table.description, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get endedAt =>
      $composableBuilder(column: $table.endedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get peak =>
      $composableBuilder(column: $table.peak, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get failedChecks =>
      $composableBuilder(column: $table.failedChecks, builder: (column) => ColumnOrderings(column));

  $$MonitorTargetsTableOrderingComposer get targetId {
    final $$MonitorTargetsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.targetId,
      referencedTable: $db.monitorTargets,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$MonitorTargetsTableOrderingComposer(
            $db: $db,
            $table: $db.monitorTargets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$IncidentsTableAnnotationComposer extends Composer<_$AppDatabase, $IncidentsTable> {
  $$IncidentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id => $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get kind => $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get title => $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get description =>
      $composableBuilder(column: $table.description, builder: (column) => column);

  GeneratedColumn<DateTime> get startedAt => $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get endedAt => $composableBuilder(column: $table.endedAt, builder: (column) => column);

  GeneratedColumn<double> get peak => $composableBuilder(column: $table.peak, builder: (column) => column);

  GeneratedColumn<int> get failedChecks => $composableBuilder(column: $table.failedChecks, builder: (column) => column);

  $$MonitorTargetsTableAnnotationComposer get targetId {
    final $$MonitorTargetsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.targetId,
      referencedTable: $db.monitorTargets,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$MonitorTargetsTableAnnotationComposer(
            $db: $db,
            $table: $db.monitorTargets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$IncidentsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $IncidentsTable,
          Incident,
          $$IncidentsTableFilterComposer,
          $$IncidentsTableOrderingComposer,
          $$IncidentsTableAnnotationComposer,
          $$IncidentsTableCreateCompanionBuilder,
          $$IncidentsTableUpdateCompanionBuilder,
          (Incident, $$IncidentsTableReferences),
          Incident,
          PrefetchHooks Function({bool targetId})
        > {
  $$IncidentsTableTableManager(_$AppDatabase db, $IncidentsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$IncidentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$IncidentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$IncidentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> targetId = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<DateTime> startedAt = const Value.absent(),
                Value<DateTime?> endedAt = const Value.absent(),
                Value<double?> peak = const Value.absent(),
                Value<int> failedChecks = const Value.absent(),
              }) => IncidentsCompanion(
                id: id,
                targetId: targetId,
                kind: kind,
                title: title,
                description: description,
                startedAt: startedAt,
                endedAt: endedAt,
                peak: peak,
                failedChecks: failedChecks,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int targetId,
                required String kind,
                required String title,
                required String description,
                required DateTime startedAt,
                Value<DateTime?> endedAt = const Value.absent(),
                Value<double?> peak = const Value.absent(),
                Value<int> failedChecks = const Value.absent(),
              }) => IncidentsCompanion.insert(
                id: id,
                targetId: targetId,
                kind: kind,
                title: title,
                description: description,
                startedAt: startedAt,
                endedAt: endedAt,
                peak: peak,
                failedChecks: failedChecks,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable<$IncidentsTable, Incident>(table), $$IncidentsTableReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: ({targetId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (targetId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.targetId,
                                referencedTable: $$IncidentsTableReferences._targetIdTable(db),
                                referencedColumn: $$IncidentsTableReferences._targetIdTable(db).id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$IncidentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $IncidentsTable,
      Incident,
      $$IncidentsTableFilterComposer,
      $$IncidentsTableOrderingComposer,
      $$IncidentsTableAnnotationComposer,
      $$IncidentsTableCreateCompanionBuilder,
      $$IncidentsTableUpdateCompanionBuilder,
      (Incident, $$IncidentsTableReferences),
      Incident,
      PrefetchHooks Function({bool targetId})
    >;
typedef $$AlertRulesTableCreateCompanionBuilder =
    AlertRulesCompanion Function({
      Value<int> id,
      required String title,
      required String target,
      required String metric,
      Value<double> threshold,
      Value<int> forSeconds,
      Value<int> channels,
      Value<bool> enabled,
      required DateTime createdAt,
      Value<DateTime?> breachSince,
      Value<bool> firing,
      Value<DateTime?> lastFiredAt,
    });
typedef $$AlertRulesTableUpdateCompanionBuilder =
    AlertRulesCompanion Function({
      Value<int> id,
      Value<String> title,
      Value<String> target,
      Value<String> metric,
      Value<double> threshold,
      Value<int> forSeconds,
      Value<int> channels,
      Value<bool> enabled,
      Value<DateTime> createdAt,
      Value<DateTime?> breachSince,
      Value<bool> firing,
      Value<DateTime?> lastFiredAt,
    });

final class $$AlertRulesTableReferences extends BaseReferences<_$AppDatabase, $AlertRulesTable, AlertRule> {
  $$AlertRulesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$AlertEventsTable, List<AlertEvent>> _alertEventsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(db.alertEvents, aliasName: 'alert_rules__id__alert_events__rule_id');

  $$AlertEventsTableProcessedTableManager get alertEventsRefs {
    final manager = $$AlertEventsTableTableManager(
      $_db,
      $_db.alertEvents,
    ).filter((f) => f.ruleId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_alertEventsRefsTable($_db));
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$AlertRulesTableFilterComposer extends Composer<_$AppDatabase, $AlertRulesTable> {
  $$AlertRulesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get target =>
      $composableBuilder(column: $table.target, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get metric =>
      $composableBuilder(column: $table.metric, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get threshold =>
      $composableBuilder(column: $table.threshold, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get forSeconds =>
      $composableBuilder(column: $table.forSeconds, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get channels =>
      $composableBuilder(column: $table.channels, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get enabled =>
      $composableBuilder(column: $table.enabled, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get breachSince =>
      $composableBuilder(column: $table.breachSince, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get firing =>
      $composableBuilder(column: $table.firing, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastFiredAt =>
      $composableBuilder(column: $table.lastFiredAt, builder: (column) => ColumnFilters(column));

  Expression<bool> alertEventsRefs(Expression<bool> Function($$AlertEventsTableFilterComposer f) f) {
    final $$AlertEventsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.alertEvents,
      getReferencedColumn: (t) => t.ruleId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$AlertEventsTableFilterComposer(
            $db: $db,
            $table: $db.alertEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$AlertRulesTableOrderingComposer extends Composer<_$AppDatabase, $AlertRulesTable> {
  $$AlertRulesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get target =>
      $composableBuilder(column: $table.target, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get metric =>
      $composableBuilder(column: $table.metric, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get threshold =>
      $composableBuilder(column: $table.threshold, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get forSeconds =>
      $composableBuilder(column: $table.forSeconds, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get channels =>
      $composableBuilder(column: $table.channels, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get enabled =>
      $composableBuilder(column: $table.enabled, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get breachSince =>
      $composableBuilder(column: $table.breachSince, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get firing =>
      $composableBuilder(column: $table.firing, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastFiredAt =>
      $composableBuilder(column: $table.lastFiredAt, builder: (column) => ColumnOrderings(column));
}

class $$AlertRulesTableAnnotationComposer extends Composer<_$AppDatabase, $AlertRulesTable> {
  $$AlertRulesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id => $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title => $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get target => $composableBuilder(column: $table.target, builder: (column) => column);

  GeneratedColumn<String> get metric => $composableBuilder(column: $table.metric, builder: (column) => column);

  GeneratedColumn<double> get threshold => $composableBuilder(column: $table.threshold, builder: (column) => column);

  GeneratedColumn<int> get forSeconds => $composableBuilder(column: $table.forSeconds, builder: (column) => column);

  GeneratedColumn<int> get channels => $composableBuilder(column: $table.channels, builder: (column) => column);

  GeneratedColumn<bool> get enabled => $composableBuilder(column: $table.enabled, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt => $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get breachSince =>
      $composableBuilder(column: $table.breachSince, builder: (column) => column);

  GeneratedColumn<bool> get firing => $composableBuilder(column: $table.firing, builder: (column) => column);

  GeneratedColumn<DateTime> get lastFiredAt =>
      $composableBuilder(column: $table.lastFiredAt, builder: (column) => column);

  Expression<T> alertEventsRefs<T extends Object>(Expression<T> Function($$AlertEventsTableAnnotationComposer a) f) {
    final $$AlertEventsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.alertEvents,
      getReferencedColumn: (t) => t.ruleId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$AlertEventsTableAnnotationComposer(
            $db: $db,
            $table: $db.alertEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$AlertRulesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AlertRulesTable,
          AlertRule,
          $$AlertRulesTableFilterComposer,
          $$AlertRulesTableOrderingComposer,
          $$AlertRulesTableAnnotationComposer,
          $$AlertRulesTableCreateCompanionBuilder,
          $$AlertRulesTableUpdateCompanionBuilder,
          (AlertRule, $$AlertRulesTableReferences),
          AlertRule,
          PrefetchHooks Function({bool alertEventsRefs})
        > {
  $$AlertRulesTableTableManager(_$AppDatabase db, $AlertRulesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$AlertRulesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$AlertRulesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$AlertRulesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> target = const Value.absent(),
                Value<String> metric = const Value.absent(),
                Value<double> threshold = const Value.absent(),
                Value<int> forSeconds = const Value.absent(),
                Value<int> channels = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> breachSince = const Value.absent(),
                Value<bool> firing = const Value.absent(),
                Value<DateTime?> lastFiredAt = const Value.absent(),
              }) => AlertRulesCompanion(
                id: id,
                title: title,
                target: target,
                metric: metric,
                threshold: threshold,
                forSeconds: forSeconds,
                channels: channels,
                enabled: enabled,
                createdAt: createdAt,
                breachSince: breachSince,
                firing: firing,
                lastFiredAt: lastFiredAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String title,
                required String target,
                required String metric,
                Value<double> threshold = const Value.absent(),
                Value<int> forSeconds = const Value.absent(),
                Value<int> channels = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                required DateTime createdAt,
                Value<DateTime?> breachSince = const Value.absent(),
                Value<bool> firing = const Value.absent(),
                Value<DateTime?> lastFiredAt = const Value.absent(),
              }) => AlertRulesCompanion.insert(
                id: id,
                title: title,
                target: target,
                metric: metric,
                threshold: threshold,
                forSeconds: forSeconds,
                channels: channels,
                enabled: enabled,
                createdAt: createdAt,
                breachSince: breachSince,
                firing: firing,
                lastFiredAt: lastFiredAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable<$AlertRulesTable, AlertRule>(table), $$AlertRulesTableReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: ({alertEventsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (alertEventsRefs) db.alertEvents],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (alertEventsRefs)
                    await $_getPrefetchedData<AlertRule, $AlertRulesTable, AlertEvent>(
                      currentTable: table,
                      referencedTable: $$AlertRulesTableReferences._alertEventsRefsTable(db),
                      managerFromTypedResult: (p0) => $$AlertRulesTableReferences(db, table, p0).alertEventsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.ruleId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$AlertRulesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AlertRulesTable,
      AlertRule,
      $$AlertRulesTableFilterComposer,
      $$AlertRulesTableOrderingComposer,
      $$AlertRulesTableAnnotationComposer,
      $$AlertRulesTableCreateCompanionBuilder,
      $$AlertRulesTableUpdateCompanionBuilder,
      (AlertRule, $$AlertRulesTableReferences),
      AlertRule,
      PrefetchHooks Function({bool alertEventsRefs})
    >;
typedef $$AlertEventsTableCreateCompanionBuilder =
    AlertEventsCompanion Function({
      Value<int> id,
      required int ruleId,
      required DateTime at,
      required String message,
      Value<double?> value,
      Value<bool> dismissed,
    });
typedef $$AlertEventsTableUpdateCompanionBuilder =
    AlertEventsCompanion Function({
      Value<int> id,
      Value<int> ruleId,
      Value<DateTime> at,
      Value<String> message,
      Value<double?> value,
      Value<bool> dismissed,
    });

final class $$AlertEventsTableReferences extends BaseReferences<_$AppDatabase, $AlertEventsTable, AlertEvent> {
  $$AlertEventsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $AlertRulesTable _ruleIdTable(_$AppDatabase db) =>
      db.alertRules.createAlias('alert_events__rule_id__alert_rules__id');

  $$AlertRulesTableProcessedTableManager get ruleId {
    final $_column = $_itemColumn<int>('rule_id')!;

    final manager = $$AlertRulesTableTableManager($_db, $_db.alertRules).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_ruleIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$AlertEventsTableFilterComposer extends Composer<_$AppDatabase, $AlertEventsTable> {
  $$AlertEventsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get at => $composableBuilder(column: $table.at, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get message =>
      $composableBuilder(column: $table.message, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get value =>
      $composableBuilder(column: $table.value, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get dismissed =>
      $composableBuilder(column: $table.dismissed, builder: (column) => ColumnFilters(column));

  $$AlertRulesTableFilterComposer get ruleId {
    final $$AlertRulesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.ruleId,
      referencedTable: $db.alertRules,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$AlertRulesTableFilterComposer(
            $db: $db,
            $table: $db.alertRules,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AlertEventsTableOrderingComposer extends Composer<_$AppDatabase, $AlertEventsTable> {
  $$AlertEventsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get at =>
      $composableBuilder(column: $table.at, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get message =>
      $composableBuilder(column: $table.message, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get value =>
      $composableBuilder(column: $table.value, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get dismissed =>
      $composableBuilder(column: $table.dismissed, builder: (column) => ColumnOrderings(column));

  $$AlertRulesTableOrderingComposer get ruleId {
    final $$AlertRulesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.ruleId,
      referencedTable: $db.alertRules,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$AlertRulesTableOrderingComposer(
            $db: $db,
            $table: $db.alertRules,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AlertEventsTableAnnotationComposer extends Composer<_$AppDatabase, $AlertEventsTable> {
  $$AlertEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id => $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get at => $composableBuilder(column: $table.at, builder: (column) => column);

  GeneratedColumn<String> get message => $composableBuilder(column: $table.message, builder: (column) => column);

  GeneratedColumn<double> get value => $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<bool> get dismissed => $composableBuilder(column: $table.dismissed, builder: (column) => column);

  $$AlertRulesTableAnnotationComposer get ruleId {
    final $$AlertRulesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.ruleId,
      referencedTable: $db.alertRules,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$AlertRulesTableAnnotationComposer(
            $db: $db,
            $table: $db.alertRules,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AlertEventsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AlertEventsTable,
          AlertEvent,
          $$AlertEventsTableFilterComposer,
          $$AlertEventsTableOrderingComposer,
          $$AlertEventsTableAnnotationComposer,
          $$AlertEventsTableCreateCompanionBuilder,
          $$AlertEventsTableUpdateCompanionBuilder,
          (AlertEvent, $$AlertEventsTableReferences),
          AlertEvent,
          PrefetchHooks Function({bool ruleId})
        > {
  $$AlertEventsTableTableManager(_$AppDatabase db, $AlertEventsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$AlertEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$AlertEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$AlertEventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> ruleId = const Value.absent(),
                Value<DateTime> at = const Value.absent(),
                Value<String> message = const Value.absent(),
                Value<double?> value = const Value.absent(),
                Value<bool> dismissed = const Value.absent(),
              }) => AlertEventsCompanion(
                id: id,
                ruleId: ruleId,
                at: at,
                message: message,
                value: value,
                dismissed: dismissed,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int ruleId,
                required DateTime at,
                required String message,
                Value<double?> value = const Value.absent(),
                Value<bool> dismissed = const Value.absent(),
              }) => AlertEventsCompanion.insert(
                id: id,
                ruleId: ruleId,
                at: at,
                message: message,
                value: value,
                dismissed: dismissed,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (e.readTable<$AlertEventsTable, AlertEvent>(table), $$AlertEventsTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({ruleId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (ruleId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.ruleId,
                                referencedTable: $$AlertEventsTableReferences._ruleIdTable(db),
                                referencedColumn: $$AlertEventsTableReferences._ruleIdTable(db).id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$AlertEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AlertEventsTable,
      AlertEvent,
      $$AlertEventsTableFilterComposer,
      $$AlertEventsTableOrderingComposer,
      $$AlertEventsTableAnnotationComposer,
      $$AlertEventsTableCreateCompanionBuilder,
      $$AlertEventsTableUpdateCompanionBuilder,
      (AlertEvent, $$AlertEventsTableReferences),
      AlertEvent,
      PrefetchHooks Function({bool ruleId})
    >;
typedef $$LanDevicesTableCreateCompanionBuilder =
    LanDevicesCompanion Function({
      required String key,
      required String ip,
      Value<String?> mac,
      Value<String?> hostname,
      Value<String?> vendor,
      required String subnet,
      required DateTime firstSeen,
      required DateTime lastSeen,
      Value<int> rowid,
    });
typedef $$LanDevicesTableUpdateCompanionBuilder =
    LanDevicesCompanion Function({
      Value<String> key,
      Value<String> ip,
      Value<String?> mac,
      Value<String?> hostname,
      Value<String?> vendor,
      Value<String> subnet,
      Value<DateTime> firstSeen,
      Value<DateTime> lastSeen,
      Value<int> rowid,
    });

class $$LanDevicesTableFilterComposer extends Composer<_$AppDatabase, $LanDevicesTable> {
  $$LanDevicesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(column: $table.key, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get ip => $composableBuilder(column: $table.ip, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get mac => $composableBuilder(column: $table.mac, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get hostname =>
      $composableBuilder(column: $table.hostname, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get vendor =>
      $composableBuilder(column: $table.vendor, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get subnet =>
      $composableBuilder(column: $table.subnet, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get firstSeen =>
      $composableBuilder(column: $table.firstSeen, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastSeen =>
      $composableBuilder(column: $table.lastSeen, builder: (column) => ColumnFilters(column));
}

class $$LanDevicesTableOrderingComposer extends Composer<_$AppDatabase, $LanDevicesTable> {
  $$LanDevicesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get ip => $composableBuilder(column: $table.ip, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get mac =>
      $composableBuilder(column: $table.mac, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get hostname =>
      $composableBuilder(column: $table.hostname, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get vendor =>
      $composableBuilder(column: $table.vendor, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get subnet =>
      $composableBuilder(column: $table.subnet, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get firstSeen =>
      $composableBuilder(column: $table.firstSeen, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastSeen =>
      $composableBuilder(column: $table.lastSeen, builder: (column) => ColumnOrderings(column));
}

class $$LanDevicesTableAnnotationComposer extends Composer<_$AppDatabase, $LanDevicesTable> {
  $$LanDevicesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key => $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get ip => $composableBuilder(column: $table.ip, builder: (column) => column);

  GeneratedColumn<String> get mac => $composableBuilder(column: $table.mac, builder: (column) => column);

  GeneratedColumn<String> get hostname => $composableBuilder(column: $table.hostname, builder: (column) => column);

  GeneratedColumn<String> get vendor => $composableBuilder(column: $table.vendor, builder: (column) => column);

  GeneratedColumn<String> get subnet => $composableBuilder(column: $table.subnet, builder: (column) => column);

  GeneratedColumn<DateTime> get firstSeen => $composableBuilder(column: $table.firstSeen, builder: (column) => column);

  GeneratedColumn<DateTime> get lastSeen => $composableBuilder(column: $table.lastSeen, builder: (column) => column);
}

class $$LanDevicesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LanDevicesTable,
          LanDevice,
          $$LanDevicesTableFilterComposer,
          $$LanDevicesTableOrderingComposer,
          $$LanDevicesTableAnnotationComposer,
          $$LanDevicesTableCreateCompanionBuilder,
          $$LanDevicesTableUpdateCompanionBuilder,
          (LanDevice, BaseReferences<_$AppDatabase, $LanDevicesTable, LanDevice>),
          LanDevice,
          PrefetchHooks Function()
        > {
  $$LanDevicesTableTableManager(_$AppDatabase db, $LanDevicesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$LanDevicesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$LanDevicesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$LanDevicesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> ip = const Value.absent(),
                Value<String?> mac = const Value.absent(),
                Value<String?> hostname = const Value.absent(),
                Value<String?> vendor = const Value.absent(),
                Value<String> subnet = const Value.absent(),
                Value<DateTime> firstSeen = const Value.absent(),
                Value<DateTime> lastSeen = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LanDevicesCompanion(
                key: key,
                ip: ip,
                mac: mac,
                hostname: hostname,
                vendor: vendor,
                subnet: subnet,
                firstSeen: firstSeen,
                lastSeen: lastSeen,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                required String ip,
                Value<String?> mac = const Value.absent(),
                Value<String?> hostname = const Value.absent(),
                Value<String?> vendor = const Value.absent(),
                required String subnet,
                required DateTime firstSeen,
                required DateTime lastSeen,
                Value<int> rowid = const Value.absent(),
              }) => LanDevicesCompanion.insert(
                key: key,
                ip: ip,
                mac: mac,
                hostname: hostname,
                vendor: vendor,
                subnet: subnet,
                firstSeen: firstSeen,
                lastSeen: lastSeen,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LanDevicesTable, LanDevice>(table),
                  BaseReferences<_$AppDatabase, $LanDevicesTable, LanDevice>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LanDevicesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LanDevicesTable,
      LanDevice,
      $$LanDevicesTableFilterComposer,
      $$LanDevicesTableOrderingComposer,
      $$LanDevicesTableAnnotationComposer,
      $$LanDevicesTableCreateCompanionBuilder,
      $$LanDevicesTableUpdateCompanionBuilder,
      (LanDevice, BaseReferences<_$AppDatabase, $LanDevicesTable, LanDevice>),
      LanDevice,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$SessionsTableTableManager get sessions => $$SessionsTableTableManager(_db, _db.sessions);
  $$SavedTargetsTableTableManager get savedTargets => $$SavedTargetsTableTableManager(_db, _db.savedTargets);
  $$MonitorTargetsTableTableManager get monitorTargets => $$MonitorTargetsTableTableManager(_db, _db.monitorTargets);
  $$MonitorChecksTableTableManager get monitorChecks => $$MonitorChecksTableTableManager(_db, _db.monitorChecks);
  $$IncidentsTableTableManager get incidents => $$IncidentsTableTableManager(_db, _db.incidents);
  $$AlertRulesTableTableManager get alertRules => $$AlertRulesTableTableManager(_db, _db.alertRules);
  $$AlertEventsTableTableManager get alertEvents => $$AlertEventsTableTableManager(_db, _db.alertEvents);
  $$LanDevicesTableTableManager get lanDevices => $$LanDevicesTableTableManager(_db, _db.lanDevices);
}
