// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'db.dart';

// ignore_for_file: type=lint
class $SignsTable extends Signs with TableInfo<$SignsTable, Sign> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SignsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _spokenTextMeta = const VerificationMeta(
    'spokenText',
  );
  @override
  late final GeneratedColumn<String> spokenText = GeneratedColumn<String>(
    'spoken_text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _enabledMeta = const VerificationMeta(
    'enabled',
  );
  @override
  late final GeneratedColumn<bool> enabled = GeneratedColumn<bool>(
    'enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _thresholdMeta = const VerificationMeta(
    'threshold',
  );
  @override
  late final GeneratedColumn<double> threshold = GeneratedColumn<double>(
    'threshold',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sampleCountMeta = const VerificationMeta(
    'sampleCount',
  );
  @override
  late final GeneratedColumn<int> sampleCount = GeneratedColumn<int>(
    'sample_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    label,
    spokenText,
    createdAt,
    enabled,
    threshold,
    sampleCount,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'signs';
  @override
  VerificationContext validateIntegrity(
    Insertable<Sign> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('label')) {
      context.handle(
        _labelMeta,
        label.isAcceptableOrUnknown(data['label']!, _labelMeta),
      );
    } else if (isInserting) {
      context.missing(_labelMeta);
    }
    if (data.containsKey('spoken_text')) {
      context.handle(
        _spokenTextMeta,
        spokenText.isAcceptableOrUnknown(data['spoken_text']!, _spokenTextMeta),
      );
    } else if (isInserting) {
      context.missing(_spokenTextMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('enabled')) {
      context.handle(
        _enabledMeta,
        enabled.isAcceptableOrUnknown(data['enabled']!, _enabledMeta),
      );
    }
    if (data.containsKey('threshold')) {
      context.handle(
        _thresholdMeta,
        threshold.isAcceptableOrUnknown(data['threshold']!, _thresholdMeta),
      );
    } else if (isInserting) {
      context.missing(_thresholdMeta);
    }
    if (data.containsKey('sample_count')) {
      context.handle(
        _sampleCountMeta,
        sampleCount.isAcceptableOrUnknown(
          data['sample_count']!,
          _sampleCountMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Sign map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Sign(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label'],
      )!,
      spokenText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}spoken_text'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      enabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}enabled'],
      )!,
      threshold: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}threshold'],
      )!,
      sampleCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sample_count'],
      )!,
    );
  }

  @override
  $SignsTable createAlias(String alias) {
    return $SignsTable(attachedDatabase, alias);
  }
}

class Sign extends DataClass implements Insertable<Sign> {
  final int id;
  final String label;
  final String spokenText;
  final DateTime createdAt;
  final bool enabled;
  final double threshold;
  final int sampleCount;
  const Sign({
    required this.id,
    required this.label,
    required this.spokenText,
    required this.createdAt,
    required this.enabled,
    required this.threshold,
    required this.sampleCount,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['label'] = Variable<String>(label);
    map['spoken_text'] = Variable<String>(spokenText);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['enabled'] = Variable<bool>(enabled);
    map['threshold'] = Variable<double>(threshold);
    map['sample_count'] = Variable<int>(sampleCount);
    return map;
  }

  SignsCompanion toCompanion(bool nullToAbsent) {
    return SignsCompanion(
      id: Value(id),
      label: Value(label),
      spokenText: Value(spokenText),
      createdAt: Value(createdAt),
      enabled: Value(enabled),
      threshold: Value(threshold),
      sampleCount: Value(sampleCount),
    );
  }

  factory Sign.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Sign(
      id: serializer.fromJson<int>(json['id']),
      label: serializer.fromJson<String>(json['label']),
      spokenText: serializer.fromJson<String>(json['spokenText']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      enabled: serializer.fromJson<bool>(json['enabled']),
      threshold: serializer.fromJson<double>(json['threshold']),
      sampleCount: serializer.fromJson<int>(json['sampleCount']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'label': serializer.toJson<String>(label),
      'spokenText': serializer.toJson<String>(spokenText),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'enabled': serializer.toJson<bool>(enabled),
      'threshold': serializer.toJson<double>(threshold),
      'sampleCount': serializer.toJson<int>(sampleCount),
    };
  }

  Sign copyWith({
    int? id,
    String? label,
    String? spokenText,
    DateTime? createdAt,
    bool? enabled,
    double? threshold,
    int? sampleCount,
  }) => Sign(
    id: id ?? this.id,
    label: label ?? this.label,
    spokenText: spokenText ?? this.spokenText,
    createdAt: createdAt ?? this.createdAt,
    enabled: enabled ?? this.enabled,
    threshold: threshold ?? this.threshold,
    sampleCount: sampleCount ?? this.sampleCount,
  );
  Sign copyWithCompanion(SignsCompanion data) {
    return Sign(
      id: data.id.present ? data.id.value : this.id,
      label: data.label.present ? data.label.value : this.label,
      spokenText: data.spokenText.present
          ? data.spokenText.value
          : this.spokenText,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      enabled: data.enabled.present ? data.enabled.value : this.enabled,
      threshold: data.threshold.present ? data.threshold.value : this.threshold,
      sampleCount: data.sampleCount.present
          ? data.sampleCount.value
          : this.sampleCount,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Sign(')
          ..write('id: $id, ')
          ..write('label: $label, ')
          ..write('spokenText: $spokenText, ')
          ..write('createdAt: $createdAt, ')
          ..write('enabled: $enabled, ')
          ..write('threshold: $threshold, ')
          ..write('sampleCount: $sampleCount')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    label,
    spokenText,
    createdAt,
    enabled,
    threshold,
    sampleCount,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Sign &&
          other.id == this.id &&
          other.label == this.label &&
          other.spokenText == this.spokenText &&
          other.createdAt == this.createdAt &&
          other.enabled == this.enabled &&
          other.threshold == this.threshold &&
          other.sampleCount == this.sampleCount);
}

class SignsCompanion extends UpdateCompanion<Sign> {
  final Value<int> id;
  final Value<String> label;
  final Value<String> spokenText;
  final Value<DateTime> createdAt;
  final Value<bool> enabled;
  final Value<double> threshold;
  final Value<int> sampleCount;
  const SignsCompanion({
    this.id = const Value.absent(),
    this.label = const Value.absent(),
    this.spokenText = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.enabled = const Value.absent(),
    this.threshold = const Value.absent(),
    this.sampleCount = const Value.absent(),
  });
  SignsCompanion.insert({
    this.id = const Value.absent(),
    required String label,
    required String spokenText,
    this.createdAt = const Value.absent(),
    this.enabled = const Value.absent(),
    required double threshold,
    this.sampleCount = const Value.absent(),
  }) : label = Value(label),
       spokenText = Value(spokenText),
       threshold = Value(threshold);
  static Insertable<Sign> custom({
    Expression<int>? id,
    Expression<String>? label,
    Expression<String>? spokenText,
    Expression<DateTime>? createdAt,
    Expression<bool>? enabled,
    Expression<double>? threshold,
    Expression<int>? sampleCount,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (label != null) 'label': label,
      if (spokenText != null) 'spoken_text': spokenText,
      if (createdAt != null) 'created_at': createdAt,
      if (enabled != null) 'enabled': enabled,
      if (threshold != null) 'threshold': threshold,
      if (sampleCount != null) 'sample_count': sampleCount,
    });
  }

  SignsCompanion copyWith({
    Value<int>? id,
    Value<String>? label,
    Value<String>? spokenText,
    Value<DateTime>? createdAt,
    Value<bool>? enabled,
    Value<double>? threshold,
    Value<int>? sampleCount,
  }) {
    return SignsCompanion(
      id: id ?? this.id,
      label: label ?? this.label,
      spokenText: spokenText ?? this.spokenText,
      createdAt: createdAt ?? this.createdAt,
      enabled: enabled ?? this.enabled,
      threshold: threshold ?? this.threshold,
      sampleCount: sampleCount ?? this.sampleCount,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (spokenText.present) {
      map['spoken_text'] = Variable<String>(spokenText.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (enabled.present) {
      map['enabled'] = Variable<bool>(enabled.value);
    }
    if (threshold.present) {
      map['threshold'] = Variable<double>(threshold.value);
    }
    if (sampleCount.present) {
      map['sample_count'] = Variable<int>(sampleCount.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SignsCompanion(')
          ..write('id: $id, ')
          ..write('label: $label, ')
          ..write('spokenText: $spokenText, ')
          ..write('createdAt: $createdAt, ')
          ..write('enabled: $enabled, ')
          ..write('threshold: $threshold, ')
          ..write('sampleCount: $sampleCount')
          ..write(')'))
        .toString();
  }
}

class $ExemplarsTable extends Exemplars
    with TableInfo<$ExemplarsTable, Exemplar> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ExemplarsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _signIdMeta = const VerificationMeta('signId');
  @override
  late final GeneratedColumn<int> signId = GeneratedColumn<int>(
    'sign_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES signs (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _landmarkSequenceMeta = const VerificationMeta(
    'landmarkSequence',
  );
  @override
  late final GeneratedColumn<Uint8List> landmarkSequence =
      GeneratedColumn<Uint8List>(
        'landmark_sequence',
        aliasedName,
        false,
        type: DriftSqlType.blob,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _recordedAtMeta = const VerificationMeta(
    'recordedAt',
  );
  @override
  late final GeneratedColumn<DateTime> recordedAt = GeneratedColumn<DateTime>(
    'recorded_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    signId,
    landmarkSequence,
    recordedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'exemplars';
  @override
  VerificationContext validateIntegrity(
    Insertable<Exemplar> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('sign_id')) {
      context.handle(
        _signIdMeta,
        signId.isAcceptableOrUnknown(data['sign_id']!, _signIdMeta),
      );
    } else if (isInserting) {
      context.missing(_signIdMeta);
    }
    if (data.containsKey('landmark_sequence')) {
      context.handle(
        _landmarkSequenceMeta,
        landmarkSequence.isAcceptableOrUnknown(
          data['landmark_sequence']!,
          _landmarkSequenceMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_landmarkSequenceMeta);
    }
    if (data.containsKey('recorded_at')) {
      context.handle(
        _recordedAtMeta,
        recordedAt.isAcceptableOrUnknown(data['recorded_at']!, _recordedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Exemplar map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Exemplar(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      signId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sign_id'],
      )!,
      landmarkSequence: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}landmark_sequence'],
      )!,
      recordedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}recorded_at'],
      )!,
    );
  }

  @override
  $ExemplarsTable createAlias(String alias) {
    return $ExemplarsTable(attachedDatabase, alias);
  }
}

class Exemplar extends DataClass implements Insertable<Exemplar> {
  final int id;
  final int signId;
  final Uint8List landmarkSequence;
  final DateTime recordedAt;
  const Exemplar({
    required this.id,
    required this.signId,
    required this.landmarkSequence,
    required this.recordedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['sign_id'] = Variable<int>(signId);
    map['landmark_sequence'] = Variable<Uint8List>(landmarkSequence);
    map['recorded_at'] = Variable<DateTime>(recordedAt);
    return map;
  }

  ExemplarsCompanion toCompanion(bool nullToAbsent) {
    return ExemplarsCompanion(
      id: Value(id),
      signId: Value(signId),
      landmarkSequence: Value(landmarkSequence),
      recordedAt: Value(recordedAt),
    );
  }

  factory Exemplar.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Exemplar(
      id: serializer.fromJson<int>(json['id']),
      signId: serializer.fromJson<int>(json['signId']),
      landmarkSequence: serializer.fromJson<Uint8List>(
        json['landmarkSequence'],
      ),
      recordedAt: serializer.fromJson<DateTime>(json['recordedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'signId': serializer.toJson<int>(signId),
      'landmarkSequence': serializer.toJson<Uint8List>(landmarkSequence),
      'recordedAt': serializer.toJson<DateTime>(recordedAt),
    };
  }

  Exemplar copyWith({
    int? id,
    int? signId,
    Uint8List? landmarkSequence,
    DateTime? recordedAt,
  }) => Exemplar(
    id: id ?? this.id,
    signId: signId ?? this.signId,
    landmarkSequence: landmarkSequence ?? this.landmarkSequence,
    recordedAt: recordedAt ?? this.recordedAt,
  );
  Exemplar copyWithCompanion(ExemplarsCompanion data) {
    return Exemplar(
      id: data.id.present ? data.id.value : this.id,
      signId: data.signId.present ? data.signId.value : this.signId,
      landmarkSequence: data.landmarkSequence.present
          ? data.landmarkSequence.value
          : this.landmarkSequence,
      recordedAt: data.recordedAt.present
          ? data.recordedAt.value
          : this.recordedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Exemplar(')
          ..write('id: $id, ')
          ..write('signId: $signId, ')
          ..write('landmarkSequence: $landmarkSequence, ')
          ..write('recordedAt: $recordedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    signId,
    $driftBlobEquality.hash(landmarkSequence),
    recordedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Exemplar &&
          other.id == this.id &&
          other.signId == this.signId &&
          $driftBlobEquality.equals(
            other.landmarkSequence,
            this.landmarkSequence,
          ) &&
          other.recordedAt == this.recordedAt);
}

class ExemplarsCompanion extends UpdateCompanion<Exemplar> {
  final Value<int> id;
  final Value<int> signId;
  final Value<Uint8List> landmarkSequence;
  final Value<DateTime> recordedAt;
  const ExemplarsCompanion({
    this.id = const Value.absent(),
    this.signId = const Value.absent(),
    this.landmarkSequence = const Value.absent(),
    this.recordedAt = const Value.absent(),
  });
  ExemplarsCompanion.insert({
    this.id = const Value.absent(),
    required int signId,
    required Uint8List landmarkSequence,
    this.recordedAt = const Value.absent(),
  }) : signId = Value(signId),
       landmarkSequence = Value(landmarkSequence);
  static Insertable<Exemplar> custom({
    Expression<int>? id,
    Expression<int>? signId,
    Expression<Uint8List>? landmarkSequence,
    Expression<DateTime>? recordedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (signId != null) 'sign_id': signId,
      if (landmarkSequence != null) 'landmark_sequence': landmarkSequence,
      if (recordedAt != null) 'recorded_at': recordedAt,
    });
  }

  ExemplarsCompanion copyWith({
    Value<int>? id,
    Value<int>? signId,
    Value<Uint8List>? landmarkSequence,
    Value<DateTime>? recordedAt,
  }) {
    return ExemplarsCompanion(
      id: id ?? this.id,
      signId: signId ?? this.signId,
      landmarkSequence: landmarkSequence ?? this.landmarkSequence,
      recordedAt: recordedAt ?? this.recordedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (signId.present) {
      map['sign_id'] = Variable<int>(signId.value);
    }
    if (landmarkSequence.present) {
      map['landmark_sequence'] = Variable<Uint8List>(landmarkSequence.value);
    }
    if (recordedAt.present) {
      map['recorded_at'] = Variable<DateTime>(recordedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ExemplarsCompanion(')
          ..write('id: $id, ')
          ..write('signId: $signId, ')
          ..write('landmarkSequence: $landmarkSequence, ')
          ..write('recordedAt: $recordedAt')
          ..write(')'))
        .toString();
  }
}

class $HistoryEntriesTable extends HistoryEntries
    with TableInfo<$HistoryEntriesTable, HistoryEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HistoryEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _spokenTextMeta = const VerificationMeta(
    'spokenText',
  );
  @override
  late final GeneratedColumn<String> spokenText = GeneratedColumn<String>(
    'spoken_text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _spokenAtMeta = const VerificationMeta(
    'spokenAt',
  );
  @override
  late final GeneratedColumn<DateTime> spokenAt = GeneratedColumn<DateTime>(
    'spoken_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [id, spokenText, spokenAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'history_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<HistoryEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('spoken_text')) {
      context.handle(
        _spokenTextMeta,
        spokenText.isAcceptableOrUnknown(data['spoken_text']!, _spokenTextMeta),
      );
    } else if (isInserting) {
      context.missing(_spokenTextMeta);
    }
    if (data.containsKey('spoken_at')) {
      context.handle(
        _spokenAtMeta,
        spokenAt.isAcceptableOrUnknown(data['spoken_at']!, _spokenAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  HistoryEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return HistoryEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      spokenText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}spoken_text'],
      )!,
      spokenAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}spoken_at'],
      )!,
    );
  }

  @override
  $HistoryEntriesTable createAlias(String alias) {
    return $HistoryEntriesTable(attachedDatabase, alias);
  }
}

class HistoryEntry extends DataClass implements Insertable<HistoryEntry> {
  final int id;
  final String spokenText;
  final DateTime spokenAt;
  const HistoryEntry({
    required this.id,
    required this.spokenText,
    required this.spokenAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['spoken_text'] = Variable<String>(spokenText);
    map['spoken_at'] = Variable<DateTime>(spokenAt);
    return map;
  }

  HistoryEntriesCompanion toCompanion(bool nullToAbsent) {
    return HistoryEntriesCompanion(
      id: Value(id),
      spokenText: Value(spokenText),
      spokenAt: Value(spokenAt),
    );
  }

  factory HistoryEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return HistoryEntry(
      id: serializer.fromJson<int>(json['id']),
      spokenText: serializer.fromJson<String>(json['spokenText']),
      spokenAt: serializer.fromJson<DateTime>(json['spokenAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'spokenText': serializer.toJson<String>(spokenText),
      'spokenAt': serializer.toJson<DateTime>(spokenAt),
    };
  }

  HistoryEntry copyWith({int? id, String? spokenText, DateTime? spokenAt}) =>
      HistoryEntry(
        id: id ?? this.id,
        spokenText: spokenText ?? this.spokenText,
        spokenAt: spokenAt ?? this.spokenAt,
      );
  HistoryEntry copyWithCompanion(HistoryEntriesCompanion data) {
    return HistoryEntry(
      id: data.id.present ? data.id.value : this.id,
      spokenText: data.spokenText.present
          ? data.spokenText.value
          : this.spokenText,
      spokenAt: data.spokenAt.present ? data.spokenAt.value : this.spokenAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('HistoryEntry(')
          ..write('id: $id, ')
          ..write('spokenText: $spokenText, ')
          ..write('spokenAt: $spokenAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, spokenText, spokenAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HistoryEntry &&
          other.id == this.id &&
          other.spokenText == this.spokenText &&
          other.spokenAt == this.spokenAt);
}

class HistoryEntriesCompanion extends UpdateCompanion<HistoryEntry> {
  final Value<int> id;
  final Value<String> spokenText;
  final Value<DateTime> spokenAt;
  const HistoryEntriesCompanion({
    this.id = const Value.absent(),
    this.spokenText = const Value.absent(),
    this.spokenAt = const Value.absent(),
  });
  HistoryEntriesCompanion.insert({
    this.id = const Value.absent(),
    required String spokenText,
    this.spokenAt = const Value.absent(),
  }) : spokenText = Value(spokenText);
  static Insertable<HistoryEntry> custom({
    Expression<int>? id,
    Expression<String>? spokenText,
    Expression<DateTime>? spokenAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (spokenText != null) 'spoken_text': spokenText,
      if (spokenAt != null) 'spoken_at': spokenAt,
    });
  }

  HistoryEntriesCompanion copyWith({
    Value<int>? id,
    Value<String>? spokenText,
    Value<DateTime>? spokenAt,
  }) {
    return HistoryEntriesCompanion(
      id: id ?? this.id,
      spokenText: spokenText ?? this.spokenText,
      spokenAt: spokenAt ?? this.spokenAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (spokenText.present) {
      map['spoken_text'] = Variable<String>(spokenText.value);
    }
    if (spokenAt.present) {
      map['spoken_at'] = Variable<DateTime>(spokenAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HistoryEntriesCompanion(')
          ..write('id: $id, ')
          ..write('spokenText: $spokenText, ')
          ..write('spokenAt: $spokenAt')
          ..write(')'))
        .toString();
  }
}

class $PhrasesTable extends Phrases with TableInfo<$PhrasesTable, Phrase> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PhrasesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _phraseTextMeta = const VerificationMeta(
    'phraseText',
  );
  @override
  late final GeneratedColumn<String> phraseText = GeneratedColumn<String>(
    'phrase_text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [id, phraseText, sortOrder];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'phrases';
  @override
  VerificationContext validateIntegrity(
    Insertable<Phrase> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('phrase_text')) {
      context.handle(
        _phraseTextMeta,
        phraseText.isAcceptableOrUnknown(data['phrase_text']!, _phraseTextMeta),
      );
    } else if (isInserting) {
      context.missing(_phraseTextMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Phrase map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Phrase(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      phraseText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}phrase_text'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
    );
  }

  @override
  $PhrasesTable createAlias(String alias) {
    return $PhrasesTable(attachedDatabase, alias);
  }
}

class Phrase extends DataClass implements Insertable<Phrase> {
  final int id;
  final String phraseText;
  final int sortOrder;
  const Phrase({
    required this.id,
    required this.phraseText,
    required this.sortOrder,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['phrase_text'] = Variable<String>(phraseText);
    map['sort_order'] = Variable<int>(sortOrder);
    return map;
  }

  PhrasesCompanion toCompanion(bool nullToAbsent) {
    return PhrasesCompanion(
      id: Value(id),
      phraseText: Value(phraseText),
      sortOrder: Value(sortOrder),
    );
  }

  factory Phrase.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Phrase(
      id: serializer.fromJson<int>(json['id']),
      phraseText: serializer.fromJson<String>(json['phraseText']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'phraseText': serializer.toJson<String>(phraseText),
      'sortOrder': serializer.toJson<int>(sortOrder),
    };
  }

  Phrase copyWith({int? id, String? phraseText, int? sortOrder}) => Phrase(
    id: id ?? this.id,
    phraseText: phraseText ?? this.phraseText,
    sortOrder: sortOrder ?? this.sortOrder,
  );
  Phrase copyWithCompanion(PhrasesCompanion data) {
    return Phrase(
      id: data.id.present ? data.id.value : this.id,
      phraseText: data.phraseText.present
          ? data.phraseText.value
          : this.phraseText,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Phrase(')
          ..write('id: $id, ')
          ..write('phraseText: $phraseText, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, phraseText, sortOrder);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Phrase &&
          other.id == this.id &&
          other.phraseText == this.phraseText &&
          other.sortOrder == this.sortOrder);
}

class PhrasesCompanion extends UpdateCompanion<Phrase> {
  final Value<int> id;
  final Value<String> phraseText;
  final Value<int> sortOrder;
  const PhrasesCompanion({
    this.id = const Value.absent(),
    this.phraseText = const Value.absent(),
    this.sortOrder = const Value.absent(),
  });
  PhrasesCompanion.insert({
    this.id = const Value.absent(),
    required String phraseText,
    this.sortOrder = const Value.absent(),
  }) : phraseText = Value(phraseText);
  static Insertable<Phrase> custom({
    Expression<int>? id,
    Expression<String>? phraseText,
    Expression<int>? sortOrder,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (phraseText != null) 'phrase_text': phraseText,
      if (sortOrder != null) 'sort_order': sortOrder,
    });
  }

  PhrasesCompanion copyWith({
    Value<int>? id,
    Value<String>? phraseText,
    Value<int>? sortOrder,
  }) {
    return PhrasesCompanion(
      id: id ?? this.id,
      phraseText: phraseText ?? this.phraseText,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (phraseText.present) {
      map['phrase_text'] = Variable<String>(phraseText.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PhrasesCompanion(')
          ..write('id: $id, ')
          ..write('phraseText: $phraseText, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $SignsTable signs = $SignsTable(this);
  late final $ExemplarsTable exemplars = $ExemplarsTable(this);
  late final $HistoryEntriesTable historyEntries = $HistoryEntriesTable(this);
  late final $PhrasesTable phrases = $PhrasesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    signs,
    exemplars,
    historyEntries,
    phrases,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'signs',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('exemplars', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$SignsTableCreateCompanionBuilder =
    SignsCompanion Function({
      Value<int> id,
      required String label,
      required String spokenText,
      Value<DateTime> createdAt,
      Value<bool> enabled,
      required double threshold,
      Value<int> sampleCount,
    });
typedef $$SignsTableUpdateCompanionBuilder =
    SignsCompanion Function({
      Value<int> id,
      Value<String> label,
      Value<String> spokenText,
      Value<DateTime> createdAt,
      Value<bool> enabled,
      Value<double> threshold,
      Value<int> sampleCount,
    });

final class $$SignsTableReferences
    extends BaseReferences<_$AppDatabase, $SignsTable, Sign> {
  $$SignsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$ExemplarsTable, List<Exemplar>>
  _exemplarsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.exemplars,
    aliasName: 'signs__id__exemplars__sign_id',
  );

  $$ExemplarsTableProcessedTableManager get exemplarsRefs {
    final manager = $$ExemplarsTableTableManager(
      $_db,
      $_db.exemplars,
    ).filter((f) => f.signId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_exemplarsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$SignsTableFilterComposer extends Composer<_$AppDatabase, $SignsTable> {
  $$SignsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get spokenText => $composableBuilder(
    column: $table.spokenText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get threshold => $composableBuilder(
    column: $table.threshold,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sampleCount => $composableBuilder(
    column: $table.sampleCount,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> exemplarsRefs(
    Expression<bool> Function($$ExemplarsTableFilterComposer f) f,
  ) {
    final $$ExemplarsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.exemplars,
      getReferencedColumn: (t) => t.signId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ExemplarsTableFilterComposer(
            $db: $db,
            $table: $db.exemplars,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SignsTableOrderingComposer
    extends Composer<_$AppDatabase, $SignsTable> {
  $$SignsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get spokenText => $composableBuilder(
    column: $table.spokenText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get threshold => $composableBuilder(
    column: $table.threshold,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sampleCount => $composableBuilder(
    column: $table.sampleCount,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SignsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SignsTable> {
  $$SignsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<String> get spokenText => $composableBuilder(
    column: $table.spokenText,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<bool> get enabled =>
      $composableBuilder(column: $table.enabled, builder: (column) => column);

  GeneratedColumn<double> get threshold =>
      $composableBuilder(column: $table.threshold, builder: (column) => column);

  GeneratedColumn<int> get sampleCount => $composableBuilder(
    column: $table.sampleCount,
    builder: (column) => column,
  );

  Expression<T> exemplarsRefs<T extends Object>(
    Expression<T> Function($$ExemplarsTableAnnotationComposer a) f,
  ) {
    final $$ExemplarsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.exemplars,
      getReferencedColumn: (t) => t.signId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ExemplarsTableAnnotationComposer(
            $db: $db,
            $table: $db.exemplars,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SignsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SignsTable,
          Sign,
          $$SignsTableFilterComposer,
          $$SignsTableOrderingComposer,
          $$SignsTableAnnotationComposer,
          $$SignsTableCreateCompanionBuilder,
          $$SignsTableUpdateCompanionBuilder,
          (Sign, $$SignsTableReferences),
          Sign,
          PrefetchHooks Function({bool exemplarsRefs})
        > {
  $$SignsTableTableManager(_$AppDatabase db, $SignsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SignsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SignsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SignsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> label = const Value.absent(),
                Value<String> spokenText = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<double> threshold = const Value.absent(),
                Value<int> sampleCount = const Value.absent(),
              }) => SignsCompanion(
                id: id,
                label: label,
                spokenText: spokenText,
                createdAt: createdAt,
                enabled: enabled,
                threshold: threshold,
                sampleCount: sampleCount,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String label,
                required String spokenText,
                Value<DateTime> createdAt = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                required double threshold,
                Value<int> sampleCount = const Value.absent(),
              }) => SignsCompanion.insert(
                id: id,
                label: label,
                spokenText: spokenText,
                createdAt: createdAt,
                enabled: enabled,
                threshold: threshold,
                sampleCount: sampleCount,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$SignsTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({exemplarsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (exemplarsRefs) db.exemplars],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (exemplarsRefs)
                    await $_getPrefetchedData<Sign, $SignsTable, Exemplar>(
                      currentTable: table,
                      referencedTable: $$SignsTableReferences
                          ._exemplarsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$SignsTableReferences(db, table, p0).exemplarsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.signId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$SignsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SignsTable,
      Sign,
      $$SignsTableFilterComposer,
      $$SignsTableOrderingComposer,
      $$SignsTableAnnotationComposer,
      $$SignsTableCreateCompanionBuilder,
      $$SignsTableUpdateCompanionBuilder,
      (Sign, $$SignsTableReferences),
      Sign,
      PrefetchHooks Function({bool exemplarsRefs})
    >;
typedef $$ExemplarsTableCreateCompanionBuilder =
    ExemplarsCompanion Function({
      Value<int> id,
      required int signId,
      required Uint8List landmarkSequence,
      Value<DateTime> recordedAt,
    });
typedef $$ExemplarsTableUpdateCompanionBuilder =
    ExemplarsCompanion Function({
      Value<int> id,
      Value<int> signId,
      Value<Uint8List> landmarkSequence,
      Value<DateTime> recordedAt,
    });

final class $$ExemplarsTableReferences
    extends BaseReferences<_$AppDatabase, $ExemplarsTable, Exemplar> {
  $$ExemplarsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $SignsTable _signIdTable(_$AppDatabase db) =>
      db.signs.createAlias('exemplars__sign_id__signs__id');

  $$SignsTableProcessedTableManager get signId {
    final $_column = $_itemColumn<int>('sign_id')!;

    final manager = $$SignsTableTableManager(
      $_db,
      $_db.signs,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_signIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ExemplarsTableFilterComposer
    extends Composer<_$AppDatabase, $ExemplarsTable> {
  $$ExemplarsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get landmarkSequence => $composableBuilder(
    column: $table.landmarkSequence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get recordedAt => $composableBuilder(
    column: $table.recordedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$SignsTableFilterComposer get signId {
    final $$SignsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.signId,
      referencedTable: $db.signs,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SignsTableFilterComposer(
            $db: $db,
            $table: $db.signs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ExemplarsTableOrderingComposer
    extends Composer<_$AppDatabase, $ExemplarsTable> {
  $$ExemplarsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get landmarkSequence => $composableBuilder(
    column: $table.landmarkSequence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get recordedAt => $composableBuilder(
    column: $table.recordedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$SignsTableOrderingComposer get signId {
    final $$SignsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.signId,
      referencedTable: $db.signs,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SignsTableOrderingComposer(
            $db: $db,
            $table: $db.signs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ExemplarsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ExemplarsTable> {
  $$ExemplarsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<Uint8List> get landmarkSequence => $composableBuilder(
    column: $table.landmarkSequence,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get recordedAt => $composableBuilder(
    column: $table.recordedAt,
    builder: (column) => column,
  );

  $$SignsTableAnnotationComposer get signId {
    final $$SignsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.signId,
      referencedTable: $db.signs,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SignsTableAnnotationComposer(
            $db: $db,
            $table: $db.signs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ExemplarsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ExemplarsTable,
          Exemplar,
          $$ExemplarsTableFilterComposer,
          $$ExemplarsTableOrderingComposer,
          $$ExemplarsTableAnnotationComposer,
          $$ExemplarsTableCreateCompanionBuilder,
          $$ExemplarsTableUpdateCompanionBuilder,
          (Exemplar, $$ExemplarsTableReferences),
          Exemplar,
          PrefetchHooks Function({bool signId})
        > {
  $$ExemplarsTableTableManager(_$AppDatabase db, $ExemplarsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ExemplarsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ExemplarsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ExemplarsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> signId = const Value.absent(),
                Value<Uint8List> landmarkSequence = const Value.absent(),
                Value<DateTime> recordedAt = const Value.absent(),
              }) => ExemplarsCompanion(
                id: id,
                signId: signId,
                landmarkSequence: landmarkSequence,
                recordedAt: recordedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int signId,
                required Uint8List landmarkSequence,
                Value<DateTime> recordedAt = const Value.absent(),
              }) => ExemplarsCompanion.insert(
                id: id,
                signId: signId,
                landmarkSequence: landmarkSequence,
                recordedAt: recordedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ExemplarsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({signId = false}) {
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
                    if (signId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.signId,
                                referencedTable: $$ExemplarsTableReferences
                                    ._signIdTable(db),
                                referencedColumn: $$ExemplarsTableReferences
                                    ._signIdTable(db)
                                    .id,
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

typedef $$ExemplarsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ExemplarsTable,
      Exemplar,
      $$ExemplarsTableFilterComposer,
      $$ExemplarsTableOrderingComposer,
      $$ExemplarsTableAnnotationComposer,
      $$ExemplarsTableCreateCompanionBuilder,
      $$ExemplarsTableUpdateCompanionBuilder,
      (Exemplar, $$ExemplarsTableReferences),
      Exemplar,
      PrefetchHooks Function({bool signId})
    >;
typedef $$HistoryEntriesTableCreateCompanionBuilder =
    HistoryEntriesCompanion Function({
      Value<int> id,
      required String spokenText,
      Value<DateTime> spokenAt,
    });
typedef $$HistoryEntriesTableUpdateCompanionBuilder =
    HistoryEntriesCompanion Function({
      Value<int> id,
      Value<String> spokenText,
      Value<DateTime> spokenAt,
    });

class $$HistoryEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $HistoryEntriesTable> {
  $$HistoryEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get spokenText => $composableBuilder(
    column: $table.spokenText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get spokenAt => $composableBuilder(
    column: $table.spokenAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$HistoryEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $HistoryEntriesTable> {
  $$HistoryEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get spokenText => $composableBuilder(
    column: $table.spokenText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get spokenAt => $composableBuilder(
    column: $table.spokenAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$HistoryEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $HistoryEntriesTable> {
  $$HistoryEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get spokenText => $composableBuilder(
    column: $table.spokenText,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get spokenAt =>
      $composableBuilder(column: $table.spokenAt, builder: (column) => column);
}

class $$HistoryEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $HistoryEntriesTable,
          HistoryEntry,
          $$HistoryEntriesTableFilterComposer,
          $$HistoryEntriesTableOrderingComposer,
          $$HistoryEntriesTableAnnotationComposer,
          $$HistoryEntriesTableCreateCompanionBuilder,
          $$HistoryEntriesTableUpdateCompanionBuilder,
          (
            HistoryEntry,
            BaseReferences<_$AppDatabase, $HistoryEntriesTable, HistoryEntry>,
          ),
          HistoryEntry,
          PrefetchHooks Function()
        > {
  $$HistoryEntriesTableTableManager(
    _$AppDatabase db,
    $HistoryEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HistoryEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$HistoryEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$HistoryEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> spokenText = const Value.absent(),
                Value<DateTime> spokenAt = const Value.absent(),
              }) => HistoryEntriesCompanion(
                id: id,
                spokenText: spokenText,
                spokenAt: spokenAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String spokenText,
                Value<DateTime> spokenAt = const Value.absent(),
              }) => HistoryEntriesCompanion.insert(
                id: id,
                spokenText: spokenText,
                spokenAt: spokenAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$HistoryEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $HistoryEntriesTable,
      HistoryEntry,
      $$HistoryEntriesTableFilterComposer,
      $$HistoryEntriesTableOrderingComposer,
      $$HistoryEntriesTableAnnotationComposer,
      $$HistoryEntriesTableCreateCompanionBuilder,
      $$HistoryEntriesTableUpdateCompanionBuilder,
      (
        HistoryEntry,
        BaseReferences<_$AppDatabase, $HistoryEntriesTable, HistoryEntry>,
      ),
      HistoryEntry,
      PrefetchHooks Function()
    >;
typedef $$PhrasesTableCreateCompanionBuilder =
    PhrasesCompanion Function({
      Value<int> id,
      required String phraseText,
      Value<int> sortOrder,
    });
typedef $$PhrasesTableUpdateCompanionBuilder =
    PhrasesCompanion Function({
      Value<int> id,
      Value<String> phraseText,
      Value<int> sortOrder,
    });

class $$PhrasesTableFilterComposer
    extends Composer<_$AppDatabase, $PhrasesTable> {
  $$PhrasesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get phraseText => $composableBuilder(
    column: $table.phraseText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PhrasesTableOrderingComposer
    extends Composer<_$AppDatabase, $PhrasesTable> {
  $$PhrasesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get phraseText => $composableBuilder(
    column: $table.phraseText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PhrasesTableAnnotationComposer
    extends Composer<_$AppDatabase, $PhrasesTable> {
  $$PhrasesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get phraseText => $composableBuilder(
    column: $table.phraseText,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);
}

class $$PhrasesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PhrasesTable,
          Phrase,
          $$PhrasesTableFilterComposer,
          $$PhrasesTableOrderingComposer,
          $$PhrasesTableAnnotationComposer,
          $$PhrasesTableCreateCompanionBuilder,
          $$PhrasesTableUpdateCompanionBuilder,
          (Phrase, BaseReferences<_$AppDatabase, $PhrasesTable, Phrase>),
          Phrase,
          PrefetchHooks Function()
        > {
  $$PhrasesTableTableManager(_$AppDatabase db, $PhrasesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PhrasesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PhrasesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PhrasesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> phraseText = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
              }) => PhrasesCompanion(
                id: id,
                phraseText: phraseText,
                sortOrder: sortOrder,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String phraseText,
                Value<int> sortOrder = const Value.absent(),
              }) => PhrasesCompanion.insert(
                id: id,
                phraseText: phraseText,
                sortOrder: sortOrder,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PhrasesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PhrasesTable,
      Phrase,
      $$PhrasesTableFilterComposer,
      $$PhrasesTableOrderingComposer,
      $$PhrasesTableAnnotationComposer,
      $$PhrasesTableCreateCompanionBuilder,
      $$PhrasesTableUpdateCompanionBuilder,
      (Phrase, BaseReferences<_$AppDatabase, $PhrasesTable, Phrase>),
      Phrase,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$SignsTableTableManager get signs =>
      $$SignsTableTableManager(_db, _db.signs);
  $$ExemplarsTableTableManager get exemplars =>
      $$ExemplarsTableTableManager(_db, _db.exemplars);
  $$HistoryEntriesTableTableManager get historyEntries =>
      $$HistoryEntriesTableTableManager(_db, _db.historyEntries);
  $$PhrasesTableTableManager get phrases =>
      $$PhrasesTableTableManager(_db, _db.phrases);
}
