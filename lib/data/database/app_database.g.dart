// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $CategoriesTable extends Categories
    with TableInfo<$CategoriesTable, Category> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CategoriesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(maxTextLength: 40),
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
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'categories';
  @override
  VerificationContext validateIntegrity(
    Insertable<Category> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Category map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Category(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $CategoriesTable createAlias(String alias) {
    return $CategoriesTable(attachedDatabase, alias);
  }
}

class Category extends DataClass implements Insertable<Category> {
  final int id;
  final String name;
  final DateTime createdAt;
  const Category({
    required this.id,
    required this.name,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  CategoriesCompanion toCompanion(bool nullToAbsent) {
    return CategoriesCompanion(
      id: Value(id),
      name: Value(name),
      createdAt: Value(createdAt),
    );
  }

  factory Category.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Category(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Category copyWith({int? id, String? name, DateTime? createdAt}) => Category(
    id: id ?? this.id,
    name: name ?? this.name,
    createdAt: createdAt ?? this.createdAt,
  );
  Category copyWithCompanion(CategoriesCompanion data) {
    return Category(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Category(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Category &&
          other.id == this.id &&
          other.name == this.name &&
          other.createdAt == this.createdAt);
}

class CategoriesCompanion extends UpdateCompanion<Category> {
  final Value<int> id;
  final Value<String> name;
  final Value<DateTime> createdAt;
  const CategoriesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  CategoriesCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required DateTime createdAt,
  }) : name = Value(name),
       createdAt = Value(createdAt);
  static Insertable<Category> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  CategoriesCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<DateTime>? createdAt,
  }) {
    return CategoriesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
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
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CategoriesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $ExercisesTable extends Exercises
    with TableInfo<$ExercisesTable, Exercise> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ExercisesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(maxTextLength: 40),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<int> categoryId = GeneratedColumn<int>(
    'category_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _timesPracticedMeta = const VerificationMeta(
    'timesPracticed',
  );
  @override
  late final GeneratedColumn<int> timesPracticed = GeneratedColumn<int>(
    'times_practiced',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _totalMinutesMeta = const VerificationMeta(
    'totalMinutes',
  );
  @override
  late final GeneratedColumn<int> totalMinutes = GeneratedColumn<int>(
    'total_minutes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _highestBpmMeta = const VerificationMeta(
    'highestBpm',
  );
  @override
  late final GeneratedColumn<int> highestBpm = GeneratedColumn<int>(
    'highest_bpm',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastBpmMeta = const VerificationMeta(
    'lastBpm',
  );
  @override
  late final GeneratedColumn<int> lastBpm = GeneratedColumn<int>(
    'last_bpm',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastPracticedMeta = const VerificationMeta(
    'lastPracticed',
  );
  @override
  late final GeneratedColumn<DateTime> lastPracticed =
      GeneratedColumn<DateTime>(
        'last_practiced',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _reminderDaysMeta = const VerificationMeta(
    'reminderDays',
  );
  @override
  late final GeneratedColumn<int> reminderDays = GeneratedColumn<int>(
    'reminder_days',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(3),
  );
  static const VerificationMeta _goalBpmMeta = const VerificationMeta(
    'goalBpm',
  );
  @override
  late final GeneratedColumn<int> goalBpm = GeneratedColumn<int>(
    'goal_bpm',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _initialBpmMeta = const VerificationMeta(
    'initialBpm',
  );
  @override
  late final GeneratedColumn<int> initialBpm = GeneratedColumn<int>(
    'initial_bpm',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isArchivedMeta = const VerificationMeta(
    'isArchived',
  );
  @override
  late final GeneratedColumn<bool> isArchived = GeneratedColumn<bool>(
    'is_archived',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_archived" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _archivedIndividuallyMeta =
      const VerificationMeta('archivedIndividually');
  @override
  late final GeneratedColumn<bool> archivedIndividually = GeneratedColumn<bool>(
    'archived_individually',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("archived_individually" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _archivedCategoryBundleIdMeta =
      const VerificationMeta('archivedCategoryBundleId');
  @override
  late final GeneratedColumn<int> archivedCategoryBundleId =
      GeneratedColumn<int>(
        'archived_category_bundle_id',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    categoryId,
    timesPracticed,
    totalMinutes,
    highestBpm,
    lastBpm,
    lastPracticed,
    reminderDays,
    goalBpm,
    initialBpm,
    isArchived,
    archivedIndividually,
    archivedCategoryBundleId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'exercises';
  @override
  VerificationContext validateIntegrity(
    Insertable<Exercise> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    }
    if (data.containsKey('times_practiced')) {
      context.handle(
        _timesPracticedMeta,
        timesPracticed.isAcceptableOrUnknown(
          data['times_practiced']!,
          _timesPracticedMeta,
        ),
      );
    }
    if (data.containsKey('total_minutes')) {
      context.handle(
        _totalMinutesMeta,
        totalMinutes.isAcceptableOrUnknown(
          data['total_minutes']!,
          _totalMinutesMeta,
        ),
      );
    }
    if (data.containsKey('highest_bpm')) {
      context.handle(
        _highestBpmMeta,
        highestBpm.isAcceptableOrUnknown(data['highest_bpm']!, _highestBpmMeta),
      );
    }
    if (data.containsKey('last_bpm')) {
      context.handle(
        _lastBpmMeta,
        lastBpm.isAcceptableOrUnknown(data['last_bpm']!, _lastBpmMeta),
      );
    }
    if (data.containsKey('last_practiced')) {
      context.handle(
        _lastPracticedMeta,
        lastPracticed.isAcceptableOrUnknown(
          data['last_practiced']!,
          _lastPracticedMeta,
        ),
      );
    }
    if (data.containsKey('reminder_days')) {
      context.handle(
        _reminderDaysMeta,
        reminderDays.isAcceptableOrUnknown(
          data['reminder_days']!,
          _reminderDaysMeta,
        ),
      );
    }
    if (data.containsKey('goal_bpm')) {
      context.handle(
        _goalBpmMeta,
        goalBpm.isAcceptableOrUnknown(data['goal_bpm']!, _goalBpmMeta),
      );
    }
    if (data.containsKey('initial_bpm')) {
      context.handle(
        _initialBpmMeta,
        initialBpm.isAcceptableOrUnknown(data['initial_bpm']!, _initialBpmMeta),
      );
    }
    if (data.containsKey('is_archived')) {
      context.handle(
        _isArchivedMeta,
        isArchived.isAcceptableOrUnknown(data['is_archived']!, _isArchivedMeta),
      );
    }
    if (data.containsKey('archived_individually')) {
      context.handle(
        _archivedIndividuallyMeta,
        archivedIndividually.isAcceptableOrUnknown(
          data['archived_individually']!,
          _archivedIndividuallyMeta,
        ),
      );
    }
    if (data.containsKey('archived_category_bundle_id')) {
      context.handle(
        _archivedCategoryBundleIdMeta,
        archivedCategoryBundleId.isAcceptableOrUnknown(
          data['archived_category_bundle_id']!,
          _archivedCategoryBundleIdMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Exercise map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Exercise(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}category_id'],
      ),
      timesPracticed: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}times_practiced'],
      )!,
      totalMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_minutes'],
      )!,
      highestBpm: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}highest_bpm'],
      )!,
      lastBpm: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_bpm'],
      )!,
      lastPracticed: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_practiced'],
      ),
      reminderDays: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reminder_days'],
      )!,
      goalBpm: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}goal_bpm'],
      ),
      initialBpm: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}initial_bpm'],
      ),
      isArchived: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_archived'],
      )!,
      archivedIndividually: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}archived_individually'],
      )!,
      archivedCategoryBundleId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}archived_category_bundle_id'],
      ),
    );
  }

  @override
  $ExercisesTable createAlias(String alias) {
    return $ExercisesTable(attachedDatabase, alias);
  }
}

class Exercise extends DataClass implements Insertable<Exercise> {
  final int id;
  final String name;
  final int? categoryId;
  final int timesPracticed;
  final int totalMinutes;
  final int highestBpm;
  final int lastBpm;
  final DateTime? lastPracticed;
  final int reminderDays;
  final int? goalBpm;
  final int? initialBpm;
  final bool isArchived;
  final bool archivedIndividually;
  final int? archivedCategoryBundleId;
  const Exercise({
    required this.id,
    required this.name,
    this.categoryId,
    required this.timesPracticed,
    required this.totalMinutes,
    required this.highestBpm,
    required this.lastBpm,
    this.lastPracticed,
    required this.reminderDays,
    this.goalBpm,
    this.initialBpm,
    required this.isArchived,
    required this.archivedIndividually,
    this.archivedCategoryBundleId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || categoryId != null) {
      map['category_id'] = Variable<int>(categoryId);
    }
    map['times_practiced'] = Variable<int>(timesPracticed);
    map['total_minutes'] = Variable<int>(totalMinutes);
    map['highest_bpm'] = Variable<int>(highestBpm);
    map['last_bpm'] = Variable<int>(lastBpm);
    if (!nullToAbsent || lastPracticed != null) {
      map['last_practiced'] = Variable<DateTime>(lastPracticed);
    }
    map['reminder_days'] = Variable<int>(reminderDays);
    if (!nullToAbsent || goalBpm != null) {
      map['goal_bpm'] = Variable<int>(goalBpm);
    }
    if (!nullToAbsent || initialBpm != null) {
      map['initial_bpm'] = Variable<int>(initialBpm);
    }
    map['is_archived'] = Variable<bool>(isArchived);
    map['archived_individually'] = Variable<bool>(archivedIndividually);
    if (!nullToAbsent || archivedCategoryBundleId != null) {
      map['archived_category_bundle_id'] = Variable<int>(
        archivedCategoryBundleId,
      );
    }
    return map;
  }

  ExercisesCompanion toCompanion(bool nullToAbsent) {
    return ExercisesCompanion(
      id: Value(id),
      name: Value(name),
      categoryId: categoryId == null && nullToAbsent
          ? const Value.absent()
          : Value(categoryId),
      timesPracticed: Value(timesPracticed),
      totalMinutes: Value(totalMinutes),
      highestBpm: Value(highestBpm),
      lastBpm: Value(lastBpm),
      lastPracticed: lastPracticed == null && nullToAbsent
          ? const Value.absent()
          : Value(lastPracticed),
      reminderDays: Value(reminderDays),
      goalBpm: goalBpm == null && nullToAbsent
          ? const Value.absent()
          : Value(goalBpm),
      initialBpm: initialBpm == null && nullToAbsent
          ? const Value.absent()
          : Value(initialBpm),
      isArchived: Value(isArchived),
      archivedIndividually: Value(archivedIndividually),
      archivedCategoryBundleId: archivedCategoryBundleId == null && nullToAbsent
          ? const Value.absent()
          : Value(archivedCategoryBundleId),
    );
  }

  factory Exercise.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Exercise(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      categoryId: serializer.fromJson<int?>(json['categoryId']),
      timesPracticed: serializer.fromJson<int>(json['timesPracticed']),
      totalMinutes: serializer.fromJson<int>(json['totalMinutes']),
      highestBpm: serializer.fromJson<int>(json['highestBpm']),
      lastBpm: serializer.fromJson<int>(json['lastBpm']),
      lastPracticed: serializer.fromJson<DateTime?>(json['lastPracticed']),
      reminderDays: serializer.fromJson<int>(json['reminderDays']),
      goalBpm: serializer.fromJson<int?>(json['goalBpm']),
      initialBpm: serializer.fromJson<int?>(json['initialBpm']),
      isArchived: serializer.fromJson<bool>(json['isArchived']),
      archivedIndividually: serializer.fromJson<bool>(
        json['archivedIndividually'],
      ),
      archivedCategoryBundleId: serializer.fromJson<int?>(
        json['archivedCategoryBundleId'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'categoryId': serializer.toJson<int?>(categoryId),
      'timesPracticed': serializer.toJson<int>(timesPracticed),
      'totalMinutes': serializer.toJson<int>(totalMinutes),
      'highestBpm': serializer.toJson<int>(highestBpm),
      'lastBpm': serializer.toJson<int>(lastBpm),
      'lastPracticed': serializer.toJson<DateTime?>(lastPracticed),
      'reminderDays': serializer.toJson<int>(reminderDays),
      'goalBpm': serializer.toJson<int?>(goalBpm),
      'initialBpm': serializer.toJson<int?>(initialBpm),
      'isArchived': serializer.toJson<bool>(isArchived),
      'archivedIndividually': serializer.toJson<bool>(archivedIndividually),
      'archivedCategoryBundleId': serializer.toJson<int?>(
        archivedCategoryBundleId,
      ),
    };
  }

  Exercise copyWith({
    int? id,
    String? name,
    Value<int?> categoryId = const Value.absent(),
    int? timesPracticed,
    int? totalMinutes,
    int? highestBpm,
    int? lastBpm,
    Value<DateTime?> lastPracticed = const Value.absent(),
    int? reminderDays,
    Value<int?> goalBpm = const Value.absent(),
    Value<int?> initialBpm = const Value.absent(),
    bool? isArchived,
    bool? archivedIndividually,
    Value<int?> archivedCategoryBundleId = const Value.absent(),
  }) => Exercise(
    id: id ?? this.id,
    name: name ?? this.name,
    categoryId: categoryId.present ? categoryId.value : this.categoryId,
    timesPracticed: timesPracticed ?? this.timesPracticed,
    totalMinutes: totalMinutes ?? this.totalMinutes,
    highestBpm: highestBpm ?? this.highestBpm,
    lastBpm: lastBpm ?? this.lastBpm,
    lastPracticed: lastPracticed.present
        ? lastPracticed.value
        : this.lastPracticed,
    reminderDays: reminderDays ?? this.reminderDays,
    goalBpm: goalBpm.present ? goalBpm.value : this.goalBpm,
    initialBpm: initialBpm.present ? initialBpm.value : this.initialBpm,
    isArchived: isArchived ?? this.isArchived,
    archivedIndividually: archivedIndividually ?? this.archivedIndividually,
    archivedCategoryBundleId: archivedCategoryBundleId.present
        ? archivedCategoryBundleId.value
        : this.archivedCategoryBundleId,
  );
  Exercise copyWithCompanion(ExercisesCompanion data) {
    return Exercise(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      timesPracticed: data.timesPracticed.present
          ? data.timesPracticed.value
          : this.timesPracticed,
      totalMinutes: data.totalMinutes.present
          ? data.totalMinutes.value
          : this.totalMinutes,
      highestBpm: data.highestBpm.present
          ? data.highestBpm.value
          : this.highestBpm,
      lastBpm: data.lastBpm.present ? data.lastBpm.value : this.lastBpm,
      lastPracticed: data.lastPracticed.present
          ? data.lastPracticed.value
          : this.lastPracticed,
      reminderDays: data.reminderDays.present
          ? data.reminderDays.value
          : this.reminderDays,
      goalBpm: data.goalBpm.present ? data.goalBpm.value : this.goalBpm,
      initialBpm: data.initialBpm.present
          ? data.initialBpm.value
          : this.initialBpm,
      isArchived: data.isArchived.present
          ? data.isArchived.value
          : this.isArchived,
      archivedIndividually: data.archivedIndividually.present
          ? data.archivedIndividually.value
          : this.archivedIndividually,
      archivedCategoryBundleId: data.archivedCategoryBundleId.present
          ? data.archivedCategoryBundleId.value
          : this.archivedCategoryBundleId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Exercise(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('categoryId: $categoryId, ')
          ..write('timesPracticed: $timesPracticed, ')
          ..write('totalMinutes: $totalMinutes, ')
          ..write('highestBpm: $highestBpm, ')
          ..write('lastBpm: $lastBpm, ')
          ..write('lastPracticed: $lastPracticed, ')
          ..write('reminderDays: $reminderDays, ')
          ..write('goalBpm: $goalBpm, ')
          ..write('initialBpm: $initialBpm, ')
          ..write('isArchived: $isArchived, ')
          ..write('archivedIndividually: $archivedIndividually, ')
          ..write('archivedCategoryBundleId: $archivedCategoryBundleId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    categoryId,
    timesPracticed,
    totalMinutes,
    highestBpm,
    lastBpm,
    lastPracticed,
    reminderDays,
    goalBpm,
    initialBpm,
    isArchived,
    archivedIndividually,
    archivedCategoryBundleId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Exercise &&
          other.id == this.id &&
          other.name == this.name &&
          other.categoryId == this.categoryId &&
          other.timesPracticed == this.timesPracticed &&
          other.totalMinutes == this.totalMinutes &&
          other.highestBpm == this.highestBpm &&
          other.lastBpm == this.lastBpm &&
          other.lastPracticed == this.lastPracticed &&
          other.reminderDays == this.reminderDays &&
          other.goalBpm == this.goalBpm &&
          other.initialBpm == this.initialBpm &&
          other.isArchived == this.isArchived &&
          other.archivedIndividually == this.archivedIndividually &&
          other.archivedCategoryBundleId == this.archivedCategoryBundleId);
}

class ExercisesCompanion extends UpdateCompanion<Exercise> {
  final Value<int> id;
  final Value<String> name;
  final Value<int?> categoryId;
  final Value<int> timesPracticed;
  final Value<int> totalMinutes;
  final Value<int> highestBpm;
  final Value<int> lastBpm;
  final Value<DateTime?> lastPracticed;
  final Value<int> reminderDays;
  final Value<int?> goalBpm;
  final Value<int?> initialBpm;
  final Value<bool> isArchived;
  final Value<bool> archivedIndividually;
  final Value<int?> archivedCategoryBundleId;
  const ExercisesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.timesPracticed = const Value.absent(),
    this.totalMinutes = const Value.absent(),
    this.highestBpm = const Value.absent(),
    this.lastBpm = const Value.absent(),
    this.lastPracticed = const Value.absent(),
    this.reminderDays = const Value.absent(),
    this.goalBpm = const Value.absent(),
    this.initialBpm = const Value.absent(),
    this.isArchived = const Value.absent(),
    this.archivedIndividually = const Value.absent(),
    this.archivedCategoryBundleId = const Value.absent(),
  });
  ExercisesCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.categoryId = const Value.absent(),
    this.timesPracticed = const Value.absent(),
    this.totalMinutes = const Value.absent(),
    this.highestBpm = const Value.absent(),
    this.lastBpm = const Value.absent(),
    this.lastPracticed = const Value.absent(),
    this.reminderDays = const Value.absent(),
    this.goalBpm = const Value.absent(),
    this.initialBpm = const Value.absent(),
    this.isArchived = const Value.absent(),
    this.archivedIndividually = const Value.absent(),
    this.archivedCategoryBundleId = const Value.absent(),
  }) : name = Value(name);
  static Insertable<Exercise> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<int>? categoryId,
    Expression<int>? timesPracticed,
    Expression<int>? totalMinutes,
    Expression<int>? highestBpm,
    Expression<int>? lastBpm,
    Expression<DateTime>? lastPracticed,
    Expression<int>? reminderDays,
    Expression<int>? goalBpm,
    Expression<int>? initialBpm,
    Expression<bool>? isArchived,
    Expression<bool>? archivedIndividually,
    Expression<int>? archivedCategoryBundleId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (categoryId != null) 'category_id': categoryId,
      if (timesPracticed != null) 'times_practiced': timesPracticed,
      if (totalMinutes != null) 'total_minutes': totalMinutes,
      if (highestBpm != null) 'highest_bpm': highestBpm,
      if (lastBpm != null) 'last_bpm': lastBpm,
      if (lastPracticed != null) 'last_practiced': lastPracticed,
      if (reminderDays != null) 'reminder_days': reminderDays,
      if (goalBpm != null) 'goal_bpm': goalBpm,
      if (initialBpm != null) 'initial_bpm': initialBpm,
      if (isArchived != null) 'is_archived': isArchived,
      if (archivedIndividually != null)
        'archived_individually': archivedIndividually,
      if (archivedCategoryBundleId != null)
        'archived_category_bundle_id': archivedCategoryBundleId,
    });
  }

  ExercisesCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<int?>? categoryId,
    Value<int>? timesPracticed,
    Value<int>? totalMinutes,
    Value<int>? highestBpm,
    Value<int>? lastBpm,
    Value<DateTime?>? lastPracticed,
    Value<int>? reminderDays,
    Value<int?>? goalBpm,
    Value<int?>? initialBpm,
    Value<bool>? isArchived,
    Value<bool>? archivedIndividually,
    Value<int?>? archivedCategoryBundleId,
  }) {
    return ExercisesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      categoryId: categoryId ?? this.categoryId,
      timesPracticed: timesPracticed ?? this.timesPracticed,
      totalMinutes: totalMinutes ?? this.totalMinutes,
      highestBpm: highestBpm ?? this.highestBpm,
      lastBpm: lastBpm ?? this.lastBpm,
      lastPracticed: lastPracticed ?? this.lastPracticed,
      reminderDays: reminderDays ?? this.reminderDays,
      goalBpm: goalBpm ?? this.goalBpm,
      initialBpm: initialBpm ?? this.initialBpm,
      isArchived: isArchived ?? this.isArchived,
      archivedIndividually: archivedIndividually ?? this.archivedIndividually,
      archivedCategoryBundleId:
          archivedCategoryBundleId ?? this.archivedCategoryBundleId,
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
    if (categoryId.present) {
      map['category_id'] = Variable<int>(categoryId.value);
    }
    if (timesPracticed.present) {
      map['times_practiced'] = Variable<int>(timesPracticed.value);
    }
    if (totalMinutes.present) {
      map['total_minutes'] = Variable<int>(totalMinutes.value);
    }
    if (highestBpm.present) {
      map['highest_bpm'] = Variable<int>(highestBpm.value);
    }
    if (lastBpm.present) {
      map['last_bpm'] = Variable<int>(lastBpm.value);
    }
    if (lastPracticed.present) {
      map['last_practiced'] = Variable<DateTime>(lastPracticed.value);
    }
    if (reminderDays.present) {
      map['reminder_days'] = Variable<int>(reminderDays.value);
    }
    if (goalBpm.present) {
      map['goal_bpm'] = Variable<int>(goalBpm.value);
    }
    if (initialBpm.present) {
      map['initial_bpm'] = Variable<int>(initialBpm.value);
    }
    if (isArchived.present) {
      map['is_archived'] = Variable<bool>(isArchived.value);
    }
    if (archivedIndividually.present) {
      map['archived_individually'] = Variable<bool>(archivedIndividually.value);
    }
    if (archivedCategoryBundleId.present) {
      map['archived_category_bundle_id'] = Variable<int>(
        archivedCategoryBundleId.value,
      );
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ExercisesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('categoryId: $categoryId, ')
          ..write('timesPracticed: $timesPracticed, ')
          ..write('totalMinutes: $totalMinutes, ')
          ..write('highestBpm: $highestBpm, ')
          ..write('lastBpm: $lastBpm, ')
          ..write('lastPracticed: $lastPracticed, ')
          ..write('reminderDays: $reminderDays, ')
          ..write('goalBpm: $goalBpm, ')
          ..write('initialBpm: $initialBpm, ')
          ..write('isArchived: $isArchived, ')
          ..write('archivedIndividually: $archivedIndividually, ')
          ..write('archivedCategoryBundleId: $archivedCategoryBundleId')
          ..write(')'))
        .toString();
  }
}

class $BpmLogsTable extends BpmLogs with TableInfo<$BpmLogsTable, BpmLog> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BpmLogsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _exerciseIdMeta = const VerificationMeta(
    'exerciseId',
  );
  @override
  late final GeneratedColumn<int> exerciseId = GeneratedColumn<int>(
    'exercise_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bpmMeta = const VerificationMeta('bpm');
  @override
  late final GeneratedColumn<int> bpm = GeneratedColumn<int>(
    'bpm',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _loggedAtMeta = const VerificationMeta(
    'loggedAt',
  );
  @override
  late final GeneratedColumn<DateTime> loggedAt = GeneratedColumn<DateTime>(
    'logged_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, exerciseId, bpm, loggedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'bpm_logs';
  @override
  VerificationContext validateIntegrity(
    Insertable<BpmLog> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('exercise_id')) {
      context.handle(
        _exerciseIdMeta,
        exerciseId.isAcceptableOrUnknown(data['exercise_id']!, _exerciseIdMeta),
      );
    } else if (isInserting) {
      context.missing(_exerciseIdMeta);
    }
    if (data.containsKey('bpm')) {
      context.handle(
        _bpmMeta,
        bpm.isAcceptableOrUnknown(data['bpm']!, _bpmMeta),
      );
    } else if (isInserting) {
      context.missing(_bpmMeta);
    }
    if (data.containsKey('logged_at')) {
      context.handle(
        _loggedAtMeta,
        loggedAt.isAcceptableOrUnknown(data['logged_at']!, _loggedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_loggedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BpmLog map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BpmLog(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      exerciseId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}exercise_id'],
      )!,
      bpm: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}bpm'],
      )!,
      loggedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}logged_at'],
      )!,
    );
  }

  @override
  $BpmLogsTable createAlias(String alias) {
    return $BpmLogsTable(attachedDatabase, alias);
  }
}

class BpmLog extends DataClass implements Insertable<BpmLog> {
  final int id;
  final int exerciseId;
  final int bpm;
  final DateTime loggedAt;
  const BpmLog({
    required this.id,
    required this.exerciseId,
    required this.bpm,
    required this.loggedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['exercise_id'] = Variable<int>(exerciseId);
    map['bpm'] = Variable<int>(bpm);
    map['logged_at'] = Variable<DateTime>(loggedAt);
    return map;
  }

  BpmLogsCompanion toCompanion(bool nullToAbsent) {
    return BpmLogsCompanion(
      id: Value(id),
      exerciseId: Value(exerciseId),
      bpm: Value(bpm),
      loggedAt: Value(loggedAt),
    );
  }

  factory BpmLog.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BpmLog(
      id: serializer.fromJson<int>(json['id']),
      exerciseId: serializer.fromJson<int>(json['exerciseId']),
      bpm: serializer.fromJson<int>(json['bpm']),
      loggedAt: serializer.fromJson<DateTime>(json['loggedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'exerciseId': serializer.toJson<int>(exerciseId),
      'bpm': serializer.toJson<int>(bpm),
      'loggedAt': serializer.toJson<DateTime>(loggedAt),
    };
  }

  BpmLog copyWith({int? id, int? exerciseId, int? bpm, DateTime? loggedAt}) =>
      BpmLog(
        id: id ?? this.id,
        exerciseId: exerciseId ?? this.exerciseId,
        bpm: bpm ?? this.bpm,
        loggedAt: loggedAt ?? this.loggedAt,
      );
  BpmLog copyWithCompanion(BpmLogsCompanion data) {
    return BpmLog(
      id: data.id.present ? data.id.value : this.id,
      exerciseId: data.exerciseId.present
          ? data.exerciseId.value
          : this.exerciseId,
      bpm: data.bpm.present ? data.bpm.value : this.bpm,
      loggedAt: data.loggedAt.present ? data.loggedAt.value : this.loggedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BpmLog(')
          ..write('id: $id, ')
          ..write('exerciseId: $exerciseId, ')
          ..write('bpm: $bpm, ')
          ..write('loggedAt: $loggedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, exerciseId, bpm, loggedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BpmLog &&
          other.id == this.id &&
          other.exerciseId == this.exerciseId &&
          other.bpm == this.bpm &&
          other.loggedAt == this.loggedAt);
}

class BpmLogsCompanion extends UpdateCompanion<BpmLog> {
  final Value<int> id;
  final Value<int> exerciseId;
  final Value<int> bpm;
  final Value<DateTime> loggedAt;
  const BpmLogsCompanion({
    this.id = const Value.absent(),
    this.exerciseId = const Value.absent(),
    this.bpm = const Value.absent(),
    this.loggedAt = const Value.absent(),
  });
  BpmLogsCompanion.insert({
    this.id = const Value.absent(),
    required int exerciseId,
    required int bpm,
    required DateTime loggedAt,
  }) : exerciseId = Value(exerciseId),
       bpm = Value(bpm),
       loggedAt = Value(loggedAt);
  static Insertable<BpmLog> custom({
    Expression<int>? id,
    Expression<int>? exerciseId,
    Expression<int>? bpm,
    Expression<DateTime>? loggedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (exerciseId != null) 'exercise_id': exerciseId,
      if (bpm != null) 'bpm': bpm,
      if (loggedAt != null) 'logged_at': loggedAt,
    });
  }

  BpmLogsCompanion copyWith({
    Value<int>? id,
    Value<int>? exerciseId,
    Value<int>? bpm,
    Value<DateTime>? loggedAt,
  }) {
    return BpmLogsCompanion(
      id: id ?? this.id,
      exerciseId: exerciseId ?? this.exerciseId,
      bpm: bpm ?? this.bpm,
      loggedAt: loggedAt ?? this.loggedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (exerciseId.present) {
      map['exercise_id'] = Variable<int>(exerciseId.value);
    }
    if (bpm.present) {
      map['bpm'] = Variable<int>(bpm.value);
    }
    if (loggedAt.present) {
      map['logged_at'] = Variable<DateTime>(loggedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BpmLogsCompanion(')
          ..write('id: $id, ')
          ..write('exerciseId: $exerciseId, ')
          ..write('bpm: $bpm, ')
          ..write('loggedAt: $loggedAt')
          ..write(')'))
        .toString();
  }
}

class $ExerciseNotesTable extends ExerciseNotes
    with TableInfo<$ExerciseNotesTable, ExerciseNote> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ExerciseNotesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _exerciseIdMeta = const VerificationMeta(
    'exerciseId',
  );
  @override
  late final GeneratedColumn<int> exerciseId = GeneratedColumn<int>(
    'exercise_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _noteTextMeta = const VerificationMeta(
    'noteText',
  );
  @override
  late final GeneratedColumn<String> noteText = GeneratedColumn<String>(
    'note_text',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(maxTextLength: 300),
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
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, exerciseId, noteText, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'exercise_notes';
  @override
  VerificationContext validateIntegrity(
    Insertable<ExerciseNote> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('exercise_id')) {
      context.handle(
        _exerciseIdMeta,
        exerciseId.isAcceptableOrUnknown(data['exercise_id']!, _exerciseIdMeta),
      );
    } else if (isInserting) {
      context.missing(_exerciseIdMeta);
    }
    if (data.containsKey('note_text')) {
      context.handle(
        _noteTextMeta,
        noteText.isAcceptableOrUnknown(data['note_text']!, _noteTextMeta),
      );
    } else if (isInserting) {
      context.missing(_noteTextMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ExerciseNote map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ExerciseNote(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      exerciseId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}exercise_id'],
      )!,
      noteText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note_text'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $ExerciseNotesTable createAlias(String alias) {
    return $ExerciseNotesTable(attachedDatabase, alias);
  }
}

class ExerciseNote extends DataClass implements Insertable<ExerciseNote> {
  final int id;
  final int exerciseId;
  final String noteText;
  final DateTime createdAt;
  const ExerciseNote({
    required this.id,
    required this.exerciseId,
    required this.noteText,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['exercise_id'] = Variable<int>(exerciseId);
    map['note_text'] = Variable<String>(noteText);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ExerciseNotesCompanion toCompanion(bool nullToAbsent) {
    return ExerciseNotesCompanion(
      id: Value(id),
      exerciseId: Value(exerciseId),
      noteText: Value(noteText),
      createdAt: Value(createdAt),
    );
  }

  factory ExerciseNote.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ExerciseNote(
      id: serializer.fromJson<int>(json['id']),
      exerciseId: serializer.fromJson<int>(json['exerciseId']),
      noteText: serializer.fromJson<String>(json['noteText']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'exerciseId': serializer.toJson<int>(exerciseId),
      'noteText': serializer.toJson<String>(noteText),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  ExerciseNote copyWith({
    int? id,
    int? exerciseId,
    String? noteText,
    DateTime? createdAt,
  }) => ExerciseNote(
    id: id ?? this.id,
    exerciseId: exerciseId ?? this.exerciseId,
    noteText: noteText ?? this.noteText,
    createdAt: createdAt ?? this.createdAt,
  );
  ExerciseNote copyWithCompanion(ExerciseNotesCompanion data) {
    return ExerciseNote(
      id: data.id.present ? data.id.value : this.id,
      exerciseId: data.exerciseId.present
          ? data.exerciseId.value
          : this.exerciseId,
      noteText: data.noteText.present ? data.noteText.value : this.noteText,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ExerciseNote(')
          ..write('id: $id, ')
          ..write('exerciseId: $exerciseId, ')
          ..write('noteText: $noteText, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, exerciseId, noteText, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ExerciseNote &&
          other.id == this.id &&
          other.exerciseId == this.exerciseId &&
          other.noteText == this.noteText &&
          other.createdAt == this.createdAt);
}

class ExerciseNotesCompanion extends UpdateCompanion<ExerciseNote> {
  final Value<int> id;
  final Value<int> exerciseId;
  final Value<String> noteText;
  final Value<DateTime> createdAt;
  const ExerciseNotesCompanion({
    this.id = const Value.absent(),
    this.exerciseId = const Value.absent(),
    this.noteText = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  ExerciseNotesCompanion.insert({
    this.id = const Value.absent(),
    required int exerciseId,
    required String noteText,
    required DateTime createdAt,
  }) : exerciseId = Value(exerciseId),
       noteText = Value(noteText),
       createdAt = Value(createdAt);
  static Insertable<ExerciseNote> custom({
    Expression<int>? id,
    Expression<int>? exerciseId,
    Expression<String>? noteText,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (exerciseId != null) 'exercise_id': exerciseId,
      if (noteText != null) 'note_text': noteText,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  ExerciseNotesCompanion copyWith({
    Value<int>? id,
    Value<int>? exerciseId,
    Value<String>? noteText,
    Value<DateTime>? createdAt,
  }) {
    return ExerciseNotesCompanion(
      id: id ?? this.id,
      exerciseId: exerciseId ?? this.exerciseId,
      noteText: noteText ?? this.noteText,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (exerciseId.present) {
      map['exercise_id'] = Variable<int>(exerciseId.value);
    }
    if (noteText.present) {
      map['note_text'] = Variable<String>(noteText.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ExerciseNotesCompanion(')
          ..write('id: $id, ')
          ..write('exerciseId: $exerciseId, ')
          ..write('noteText: $noteText, ')
          ..write('createdAt: $createdAt')
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
  static const VerificationMeta _exerciseIdMeta = const VerificationMeta(
    'exerciseId',
  );
  @override
  late final GeneratedColumn<int> exerciseId = GeneratedColumn<int>(
    'exercise_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _exerciseNameMeta = const VerificationMeta(
    'exerciseName',
  );
  @override
  late final GeneratedColumn<String> exerciseName = GeneratedColumn<String>(
    'exercise_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _minutesMeta = const VerificationMeta(
    'minutes',
  );
  @override
  late final GeneratedColumn<int> minutes = GeneratedColumn<int>(
    'minutes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bpmMeta = const VerificationMeta('bpm');
  @override
  late final GeneratedColumn<int> bpm = GeneratedColumn<int>(
    'bpm',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    exerciseId,
    exerciseName,
    date,
    minutes,
    bpm,
    note,
  ];
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
    if (data.containsKey('exercise_id')) {
      context.handle(
        _exerciseIdMeta,
        exerciseId.isAcceptableOrUnknown(data['exercise_id']!, _exerciseIdMeta),
      );
    }
    if (data.containsKey('exercise_name')) {
      context.handle(
        _exerciseNameMeta,
        exerciseName.isAcceptableOrUnknown(
          data['exercise_name']!,
          _exerciseNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_exerciseNameMeta);
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('minutes')) {
      context.handle(
        _minutesMeta,
        minutes.isAcceptableOrUnknown(data['minutes']!, _minutesMeta),
      );
    } else if (isInserting) {
      context.missing(_minutesMeta);
    }
    if (data.containsKey('bpm')) {
      context.handle(
        _bpmMeta,
        bpm.isAcceptableOrUnknown(data['bpm']!, _bpmMeta),
      );
    } else if (isInserting) {
      context.missing(_bpmMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
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
      exerciseId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}exercise_id'],
      ),
      exerciseName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}exercise_name'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      )!,
      minutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}minutes'],
      )!,
      bpm: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}bpm'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
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
  final int? exerciseId;
  final String exerciseName;
  final DateTime date;
  final int minutes;
  final int bpm;
  final String note;
  const HistoryEntry({
    required this.id,
    this.exerciseId,
    required this.exerciseName,
    required this.date,
    required this.minutes,
    required this.bpm,
    required this.note,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || exerciseId != null) {
      map['exercise_id'] = Variable<int>(exerciseId);
    }
    map['exercise_name'] = Variable<String>(exerciseName);
    map['date'] = Variable<DateTime>(date);
    map['minutes'] = Variable<int>(minutes);
    map['bpm'] = Variable<int>(bpm);
    map['note'] = Variable<String>(note);
    return map;
  }

  HistoryEntriesCompanion toCompanion(bool nullToAbsent) {
    return HistoryEntriesCompanion(
      id: Value(id),
      exerciseId: exerciseId == null && nullToAbsent
          ? const Value.absent()
          : Value(exerciseId),
      exerciseName: Value(exerciseName),
      date: Value(date),
      minutes: Value(minutes),
      bpm: Value(bpm),
      note: Value(note),
    );
  }

  factory HistoryEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return HistoryEntry(
      id: serializer.fromJson<int>(json['id']),
      exerciseId: serializer.fromJson<int?>(json['exerciseId']),
      exerciseName: serializer.fromJson<String>(json['exerciseName']),
      date: serializer.fromJson<DateTime>(json['date']),
      minutes: serializer.fromJson<int>(json['minutes']),
      bpm: serializer.fromJson<int>(json['bpm']),
      note: serializer.fromJson<String>(json['note']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'exerciseId': serializer.toJson<int?>(exerciseId),
      'exerciseName': serializer.toJson<String>(exerciseName),
      'date': serializer.toJson<DateTime>(date),
      'minutes': serializer.toJson<int>(minutes),
      'bpm': serializer.toJson<int>(bpm),
      'note': serializer.toJson<String>(note),
    };
  }

  HistoryEntry copyWith({
    int? id,
    Value<int?> exerciseId = const Value.absent(),
    String? exerciseName,
    DateTime? date,
    int? minutes,
    int? bpm,
    String? note,
  }) => HistoryEntry(
    id: id ?? this.id,
    exerciseId: exerciseId.present ? exerciseId.value : this.exerciseId,
    exerciseName: exerciseName ?? this.exerciseName,
    date: date ?? this.date,
    minutes: minutes ?? this.minutes,
    bpm: bpm ?? this.bpm,
    note: note ?? this.note,
  );
  HistoryEntry copyWithCompanion(HistoryEntriesCompanion data) {
    return HistoryEntry(
      id: data.id.present ? data.id.value : this.id,
      exerciseId: data.exerciseId.present
          ? data.exerciseId.value
          : this.exerciseId,
      exerciseName: data.exerciseName.present
          ? data.exerciseName.value
          : this.exerciseName,
      date: data.date.present ? data.date.value : this.date,
      minutes: data.minutes.present ? data.minutes.value : this.minutes,
      bpm: data.bpm.present ? data.bpm.value : this.bpm,
      note: data.note.present ? data.note.value : this.note,
    );
  }

  @override
  String toString() {
    return (StringBuffer('HistoryEntry(')
          ..write('id: $id, ')
          ..write('exerciseId: $exerciseId, ')
          ..write('exerciseName: $exerciseName, ')
          ..write('date: $date, ')
          ..write('minutes: $minutes, ')
          ..write('bpm: $bpm, ')
          ..write('note: $note')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, exerciseId, exerciseName, date, minutes, bpm, note);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HistoryEntry &&
          other.id == this.id &&
          other.exerciseId == this.exerciseId &&
          other.exerciseName == this.exerciseName &&
          other.date == this.date &&
          other.minutes == this.minutes &&
          other.bpm == this.bpm &&
          other.note == this.note);
}

class HistoryEntriesCompanion extends UpdateCompanion<HistoryEntry> {
  final Value<int> id;
  final Value<int?> exerciseId;
  final Value<String> exerciseName;
  final Value<DateTime> date;
  final Value<int> minutes;
  final Value<int> bpm;
  final Value<String> note;
  const HistoryEntriesCompanion({
    this.id = const Value.absent(),
    this.exerciseId = const Value.absent(),
    this.exerciseName = const Value.absent(),
    this.date = const Value.absent(),
    this.minutes = const Value.absent(),
    this.bpm = const Value.absent(),
    this.note = const Value.absent(),
  });
  HistoryEntriesCompanion.insert({
    this.id = const Value.absent(),
    this.exerciseId = const Value.absent(),
    required String exerciseName,
    required DateTime date,
    required int minutes,
    required int bpm,
    this.note = const Value.absent(),
  }) : exerciseName = Value(exerciseName),
       date = Value(date),
       minutes = Value(minutes),
       bpm = Value(bpm);
  static Insertable<HistoryEntry> custom({
    Expression<int>? id,
    Expression<int>? exerciseId,
    Expression<String>? exerciseName,
    Expression<DateTime>? date,
    Expression<int>? minutes,
    Expression<int>? bpm,
    Expression<String>? note,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (exerciseId != null) 'exercise_id': exerciseId,
      if (exerciseName != null) 'exercise_name': exerciseName,
      if (date != null) 'date': date,
      if (minutes != null) 'minutes': minutes,
      if (bpm != null) 'bpm': bpm,
      if (note != null) 'note': note,
    });
  }

  HistoryEntriesCompanion copyWith({
    Value<int>? id,
    Value<int?>? exerciseId,
    Value<String>? exerciseName,
    Value<DateTime>? date,
    Value<int>? minutes,
    Value<int>? bpm,
    Value<String>? note,
  }) {
    return HistoryEntriesCompanion(
      id: id ?? this.id,
      exerciseId: exerciseId ?? this.exerciseId,
      exerciseName: exerciseName ?? this.exerciseName,
      date: date ?? this.date,
      minutes: minutes ?? this.minutes,
      bpm: bpm ?? this.bpm,
      note: note ?? this.note,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (exerciseId.present) {
      map['exercise_id'] = Variable<int>(exerciseId.value);
    }
    if (exerciseName.present) {
      map['exercise_name'] = Variable<String>(exerciseName.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (minutes.present) {
      map['minutes'] = Variable<int>(minutes.value);
    }
    if (bpm.present) {
      map['bpm'] = Variable<int>(bpm.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HistoryEntriesCompanion(')
          ..write('id: $id, ')
          ..write('exerciseId: $exerciseId, ')
          ..write('exerciseName: $exerciseName, ')
          ..write('date: $date, ')
          ..write('minutes: $minutes, ')
          ..write('bpm: $bpm, ')
          ..write('note: $note')
          ..write(')'))
        .toString();
  }
}

class $ArchivedCategoryBundlesTable extends ArchivedCategoryBundles
    with TableInfo<$ArchivedCategoryBundlesTable, ArchivedCategoryBundle> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ArchivedCategoryBundlesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _archivedAtMeta = const VerificationMeta(
    'archivedAt',
  );
  @override
  late final GeneratedColumn<DateTime> archivedAt = GeneratedColumn<DateTime>(
    'archived_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, archivedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'archived_category_bundles';
  @override
  VerificationContext validateIntegrity(
    Insertable<ArchivedCategoryBundle> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('archived_at')) {
      context.handle(
        _archivedAtMeta,
        archivedAt.isAcceptableOrUnknown(data['archived_at']!, _archivedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_archivedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ArchivedCategoryBundle map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ArchivedCategoryBundle(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      archivedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}archived_at'],
      )!,
    );
  }

  @override
  $ArchivedCategoryBundlesTable createAlias(String alias) {
    return $ArchivedCategoryBundlesTable(attachedDatabase, alias);
  }
}

class ArchivedCategoryBundle extends DataClass
    implements Insertable<ArchivedCategoryBundle> {
  final int id;
  final String name;
  final DateTime archivedAt;
  const ArchivedCategoryBundle({
    required this.id,
    required this.name,
    required this.archivedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['archived_at'] = Variable<DateTime>(archivedAt);
    return map;
  }

  ArchivedCategoryBundlesCompanion toCompanion(bool nullToAbsent) {
    return ArchivedCategoryBundlesCompanion(
      id: Value(id),
      name: Value(name),
      archivedAt: Value(archivedAt),
    );
  }

  factory ArchivedCategoryBundle.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ArchivedCategoryBundle(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      archivedAt: serializer.fromJson<DateTime>(json['archivedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'archivedAt': serializer.toJson<DateTime>(archivedAt),
    };
  }

  ArchivedCategoryBundle copyWith({
    int? id,
    String? name,
    DateTime? archivedAt,
  }) => ArchivedCategoryBundle(
    id: id ?? this.id,
    name: name ?? this.name,
    archivedAt: archivedAt ?? this.archivedAt,
  );
  ArchivedCategoryBundle copyWithCompanion(
    ArchivedCategoryBundlesCompanion data,
  ) {
    return ArchivedCategoryBundle(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      archivedAt: data.archivedAt.present
          ? data.archivedAt.value
          : this.archivedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ArchivedCategoryBundle(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('archivedAt: $archivedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, archivedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ArchivedCategoryBundle &&
          other.id == this.id &&
          other.name == this.name &&
          other.archivedAt == this.archivedAt);
}

class ArchivedCategoryBundlesCompanion
    extends UpdateCompanion<ArchivedCategoryBundle> {
  final Value<int> id;
  final Value<String> name;
  final Value<DateTime> archivedAt;
  const ArchivedCategoryBundlesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.archivedAt = const Value.absent(),
  });
  ArchivedCategoryBundlesCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required DateTime archivedAt,
  }) : name = Value(name),
       archivedAt = Value(archivedAt);
  static Insertable<ArchivedCategoryBundle> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<DateTime>? archivedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (archivedAt != null) 'archived_at': archivedAt,
    });
  }

  ArchivedCategoryBundlesCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<DateTime>? archivedAt,
  }) {
    return ArchivedCategoryBundlesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      archivedAt: archivedAt ?? this.archivedAt,
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
    if (archivedAt.present) {
      map['archived_at'] = Variable<DateTime>(archivedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ArchivedCategoryBundlesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('archivedAt: $archivedAt')
          ..write(')'))
        .toString();
  }
}

class $CalendarEventsTable extends CalendarEvents
    with TableInfo<$CalendarEventsTable, CalendarEvent> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CalendarEventsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(maxTextLength: 80),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _startDateMeta = const VerificationMeta(
    'startDate',
  );
  @override
  late final GeneratedColumn<DateTime> startDate = GeneratedColumn<DateTime>(
    'start_date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endDateMeta = const VerificationMeta(
    'endDate',
  );
  @override
  late final GeneratedColumn<DateTime> endDate = GeneratedColumn<DateTime>(
    'end_date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _colorValueMeta = const VerificationMeta(
    'colorValue',
  );
  @override
  late final GeneratedColumn<int> colorValue = GeneratedColumn<int>(
    'color_value',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
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
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    notes,
    startDate,
    endDate,
    colorValue,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'calendar_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<CalendarEvent> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('start_date')) {
      context.handle(
        _startDateMeta,
        startDate.isAcceptableOrUnknown(data['start_date']!, _startDateMeta),
      );
    } else if (isInserting) {
      context.missing(_startDateMeta);
    }
    if (data.containsKey('end_date')) {
      context.handle(
        _endDateMeta,
        endDate.isAcceptableOrUnknown(data['end_date']!, _endDateMeta),
      );
    } else if (isInserting) {
      context.missing(_endDateMeta);
    }
    if (data.containsKey('color_value')) {
      context.handle(
        _colorValueMeta,
        colorValue.isAcceptableOrUnknown(data['color_value']!, _colorValueMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CalendarEvent map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CalendarEvent(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      )!,
      startDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}start_date'],
      )!,
      endDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}end_date'],
      )!,
      colorValue: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}color_value'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $CalendarEventsTable createAlias(String alias) {
    return $CalendarEventsTable(attachedDatabase, alias);
  }
}

class CalendarEvent extends DataClass implements Insertable<CalendarEvent> {
  final int id;
  final String title;
  final String notes;
  final DateTime startDate;
  final DateTime endDate;
  final int? colorValue;
  final DateTime createdAt;
  const CalendarEvent({
    required this.id,
    required this.title,
    required this.notes,
    required this.startDate,
    required this.endDate,
    this.colorValue,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['title'] = Variable<String>(title);
    map['notes'] = Variable<String>(notes);
    map['start_date'] = Variable<DateTime>(startDate);
    map['end_date'] = Variable<DateTime>(endDate);
    if (!nullToAbsent || colorValue != null) {
      map['color_value'] = Variable<int>(colorValue);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  CalendarEventsCompanion toCompanion(bool nullToAbsent) {
    return CalendarEventsCompanion(
      id: Value(id),
      title: Value(title),
      notes: Value(notes),
      startDate: Value(startDate),
      endDate: Value(endDate),
      colorValue: colorValue == null && nullToAbsent
          ? const Value.absent()
          : Value(colorValue),
      createdAt: Value(createdAt),
    );
  }

  factory CalendarEvent.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CalendarEvent(
      id: serializer.fromJson<int>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      notes: serializer.fromJson<String>(json['notes']),
      startDate: serializer.fromJson<DateTime>(json['startDate']),
      endDate: serializer.fromJson<DateTime>(json['endDate']),
      colorValue: serializer.fromJson<int?>(json['colorValue']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'title': serializer.toJson<String>(title),
      'notes': serializer.toJson<String>(notes),
      'startDate': serializer.toJson<DateTime>(startDate),
      'endDate': serializer.toJson<DateTime>(endDate),
      'colorValue': serializer.toJson<int?>(colorValue),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  CalendarEvent copyWith({
    int? id,
    String? title,
    String? notes,
    DateTime? startDate,
    DateTime? endDate,
    Value<int?> colorValue = const Value.absent(),
    DateTime? createdAt,
  }) => CalendarEvent(
    id: id ?? this.id,
    title: title ?? this.title,
    notes: notes ?? this.notes,
    startDate: startDate ?? this.startDate,
    endDate: endDate ?? this.endDate,
    colorValue: colorValue.present ? colorValue.value : this.colorValue,
    createdAt: createdAt ?? this.createdAt,
  );
  CalendarEvent copyWithCompanion(CalendarEventsCompanion data) {
    return CalendarEvent(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      notes: data.notes.present ? data.notes.value : this.notes,
      startDate: data.startDate.present ? data.startDate.value : this.startDate,
      endDate: data.endDate.present ? data.endDate.value : this.endDate,
      colorValue: data.colorValue.present
          ? data.colorValue.value
          : this.colorValue,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CalendarEvent(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('notes: $notes, ')
          ..write('startDate: $startDate, ')
          ..write('endDate: $endDate, ')
          ..write('colorValue: $colorValue, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, title, notes, startDate, endDate, colorValue, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CalendarEvent &&
          other.id == this.id &&
          other.title == this.title &&
          other.notes == this.notes &&
          other.startDate == this.startDate &&
          other.endDate == this.endDate &&
          other.colorValue == this.colorValue &&
          other.createdAt == this.createdAt);
}

class CalendarEventsCompanion extends UpdateCompanion<CalendarEvent> {
  final Value<int> id;
  final Value<String> title;
  final Value<String> notes;
  final Value<DateTime> startDate;
  final Value<DateTime> endDate;
  final Value<int?> colorValue;
  final Value<DateTime> createdAt;
  const CalendarEventsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.notes = const Value.absent(),
    this.startDate = const Value.absent(),
    this.endDate = const Value.absent(),
    this.colorValue = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  CalendarEventsCompanion.insert({
    this.id = const Value.absent(),
    required String title,
    this.notes = const Value.absent(),
    required DateTime startDate,
    required DateTime endDate,
    this.colorValue = const Value.absent(),
    required DateTime createdAt,
  }) : title = Value(title),
       startDate = Value(startDate),
       endDate = Value(endDate),
       createdAt = Value(createdAt);
  static Insertable<CalendarEvent> custom({
    Expression<int>? id,
    Expression<String>? title,
    Expression<String>? notes,
    Expression<DateTime>? startDate,
    Expression<DateTime>? endDate,
    Expression<int>? colorValue,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (notes != null) 'notes': notes,
      if (startDate != null) 'start_date': startDate,
      if (endDate != null) 'end_date': endDate,
      if (colorValue != null) 'color_value': colorValue,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  CalendarEventsCompanion copyWith({
    Value<int>? id,
    Value<String>? title,
    Value<String>? notes,
    Value<DateTime>? startDate,
    Value<DateTime>? endDate,
    Value<int?>? colorValue,
    Value<DateTime>? createdAt,
  }) {
    return CalendarEventsCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      colorValue: colorValue ?? this.colorValue,
      createdAt: createdAt ?? this.createdAt,
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
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (startDate.present) {
      map['start_date'] = Variable<DateTime>(startDate.value);
    }
    if (endDate.present) {
      map['end_date'] = Variable<DateTime>(endDate.value);
    }
    if (colorValue.present) {
      map['color_value'] = Variable<int>(colorValue.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CalendarEventsCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('notes: $notes, ')
          ..write('startDate: $startDate, ')
          ..write('endDate: $endDate, ')
          ..write('colorValue: $colorValue, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $EventRemindersTable extends EventReminders
    with TableInfo<$EventRemindersTable, EventReminder> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EventRemindersTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _eventIdMeta = const VerificationMeta(
    'eventId',
  );
  @override
  late final GeneratedColumn<int> eventId = GeneratedColumn<int>(
    'event_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _daysBeforeMeta = const VerificationMeta(
    'daysBefore',
  );
  @override
  late final GeneratedColumn<int> daysBefore = GeneratedColumn<int>(
    'days_before',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _customDateMeta = const VerificationMeta(
    'customDate',
  );
  @override
  late final GeneratedColumn<DateTime> customDate = GeneratedColumn<DateTime>(
    'custom_date',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [id, eventId, daysBefore, customDate];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'event_reminders';
  @override
  VerificationContext validateIntegrity(
    Insertable<EventReminder> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('event_id')) {
      context.handle(
        _eventIdMeta,
        eventId.isAcceptableOrUnknown(data['event_id']!, _eventIdMeta),
      );
    } else if (isInserting) {
      context.missing(_eventIdMeta);
    }
    if (data.containsKey('days_before')) {
      context.handle(
        _daysBeforeMeta,
        daysBefore.isAcceptableOrUnknown(data['days_before']!, _daysBeforeMeta),
      );
    } else if (isInserting) {
      context.missing(_daysBeforeMeta);
    }
    if (data.containsKey('custom_date')) {
      context.handle(
        _customDateMeta,
        customDate.isAcceptableOrUnknown(data['custom_date']!, _customDateMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  EventReminder map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EventReminder(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      eventId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}event_id'],
      )!,
      daysBefore: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}days_before'],
      )!,
      customDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}custom_date'],
      ),
    );
  }

  @override
  $EventRemindersTable createAlias(String alias) {
    return $EventRemindersTable(attachedDatabase, alias);
  }
}

class EventReminder extends DataClass implements Insertable<EventReminder> {
  final int id;
  final int eventId;
  final int daysBefore;
  final DateTime? customDate;
  const EventReminder({
    required this.id,
    required this.eventId,
    required this.daysBefore,
    this.customDate,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['event_id'] = Variable<int>(eventId);
    map['days_before'] = Variable<int>(daysBefore);
    if (!nullToAbsent || customDate != null) {
      map['custom_date'] = Variable<DateTime>(customDate);
    }
    return map;
  }

  EventRemindersCompanion toCompanion(bool nullToAbsent) {
    return EventRemindersCompanion(
      id: Value(id),
      eventId: Value(eventId),
      daysBefore: Value(daysBefore),
      customDate: customDate == null && nullToAbsent
          ? const Value.absent()
          : Value(customDate),
    );
  }

  factory EventReminder.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EventReminder(
      id: serializer.fromJson<int>(json['id']),
      eventId: serializer.fromJson<int>(json['eventId']),
      daysBefore: serializer.fromJson<int>(json['daysBefore']),
      customDate: serializer.fromJson<DateTime?>(json['customDate']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'eventId': serializer.toJson<int>(eventId),
      'daysBefore': serializer.toJson<int>(daysBefore),
      'customDate': serializer.toJson<DateTime?>(customDate),
    };
  }

  EventReminder copyWith({
    int? id,
    int? eventId,
    int? daysBefore,
    Value<DateTime?> customDate = const Value.absent(),
  }) => EventReminder(
    id: id ?? this.id,
    eventId: eventId ?? this.eventId,
    daysBefore: daysBefore ?? this.daysBefore,
    customDate: customDate.present ? customDate.value : this.customDate,
  );
  EventReminder copyWithCompanion(EventRemindersCompanion data) {
    return EventReminder(
      id: data.id.present ? data.id.value : this.id,
      eventId: data.eventId.present ? data.eventId.value : this.eventId,
      daysBefore: data.daysBefore.present
          ? data.daysBefore.value
          : this.daysBefore,
      customDate: data.customDate.present
          ? data.customDate.value
          : this.customDate,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EventReminder(')
          ..write('id: $id, ')
          ..write('eventId: $eventId, ')
          ..write('daysBefore: $daysBefore, ')
          ..write('customDate: $customDate')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, eventId, daysBefore, customDate);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventReminder &&
          other.id == this.id &&
          other.eventId == this.eventId &&
          other.daysBefore == this.daysBefore &&
          other.customDate == this.customDate);
}

class EventRemindersCompanion extends UpdateCompanion<EventReminder> {
  final Value<int> id;
  final Value<int> eventId;
  final Value<int> daysBefore;
  final Value<DateTime?> customDate;
  const EventRemindersCompanion({
    this.id = const Value.absent(),
    this.eventId = const Value.absent(),
    this.daysBefore = const Value.absent(),
    this.customDate = const Value.absent(),
  });
  EventRemindersCompanion.insert({
    this.id = const Value.absent(),
    required int eventId,
    required int daysBefore,
    this.customDate = const Value.absent(),
  }) : eventId = Value(eventId),
       daysBefore = Value(daysBefore);
  static Insertable<EventReminder> custom({
    Expression<int>? id,
    Expression<int>? eventId,
    Expression<int>? daysBefore,
    Expression<DateTime>? customDate,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (eventId != null) 'event_id': eventId,
      if (daysBefore != null) 'days_before': daysBefore,
      if (customDate != null) 'custom_date': customDate,
    });
  }

  EventRemindersCompanion copyWith({
    Value<int>? id,
    Value<int>? eventId,
    Value<int>? daysBefore,
    Value<DateTime?>? customDate,
  }) {
    return EventRemindersCompanion(
      id: id ?? this.id,
      eventId: eventId ?? this.eventId,
      daysBefore: daysBefore ?? this.daysBefore,
      customDate: customDate ?? this.customDate,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (eventId.present) {
      map['event_id'] = Variable<int>(eventId.value);
    }
    if (daysBefore.present) {
      map['days_before'] = Variable<int>(daysBefore.value);
    }
    if (customDate.present) {
      map['custom_date'] = Variable<DateTime>(customDate.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EventRemindersCompanion(')
          ..write('id: $id, ')
          ..write('eventId: $eventId, ')
          ..write('daysBefore: $daysBefore, ')
          ..write('customDate: $customDate')
          ..write(')'))
        .toString();
  }
}

class $MetronomePiecesTable extends MetronomePieces
    with TableInfo<$MetronomePiecesTable, MetronomePiece> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MetronomePiecesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(maxTextLength: 100),
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
    requiredDuringInsert: true,
  );
  static const VerificationMeta _modifiedAtMeta = const VerificationMeta(
    'modifiedAt',
  );
  @override
  late final GeneratedColumn<DateTime> modifiedAt = GeneratedColumn<DateTime>(
    'modified_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isArchivedMeta = const VerificationMeta(
    'isArchived',
  );
  @override
  late final GeneratedColumn<bool> isArchived = GeneratedColumn<bool>(
    'is_archived',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_archived" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    createdAt,
    modifiedAt,
    isArchived,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'metronome_pieces';
  @override
  VerificationContext validateIntegrity(
    Insertable<MetronomePiece> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('modified_at')) {
      context.handle(
        _modifiedAtMeta,
        modifiedAt.isAcceptableOrUnknown(data['modified_at']!, _modifiedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_modifiedAtMeta);
    }
    if (data.containsKey('is_archived')) {
      context.handle(
        _isArchivedMeta,
        isArchived.isAcceptableOrUnknown(data['is_archived']!, _isArchivedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MetronomePiece map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MetronomePiece(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      modifiedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}modified_at'],
      )!,
      isArchived: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_archived'],
      )!,
    );
  }

  @override
  $MetronomePiecesTable createAlias(String alias) {
    return $MetronomePiecesTable(attachedDatabase, alias);
  }
}

class MetronomePiece extends DataClass implements Insertable<MetronomePiece> {
  final int id;
  final String title;
  final DateTime createdAt;
  final DateTime modifiedAt;
  final bool isArchived;
  const MetronomePiece({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.modifiedAt,
    required this.isArchived,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['title'] = Variable<String>(title);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['modified_at'] = Variable<DateTime>(modifiedAt);
    map['is_archived'] = Variable<bool>(isArchived);
    return map;
  }

  MetronomePiecesCompanion toCompanion(bool nullToAbsent) {
    return MetronomePiecesCompanion(
      id: Value(id),
      title: Value(title),
      createdAt: Value(createdAt),
      modifiedAt: Value(modifiedAt),
      isArchived: Value(isArchived),
    );
  }

  factory MetronomePiece.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MetronomePiece(
      id: serializer.fromJson<int>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      modifiedAt: serializer.fromJson<DateTime>(json['modifiedAt']),
      isArchived: serializer.fromJson<bool>(json['isArchived']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'title': serializer.toJson<String>(title),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'modifiedAt': serializer.toJson<DateTime>(modifiedAt),
      'isArchived': serializer.toJson<bool>(isArchived),
    };
  }

  MetronomePiece copyWith({
    int? id,
    String? title,
    DateTime? createdAt,
    DateTime? modifiedAt,
    bool? isArchived,
  }) => MetronomePiece(
    id: id ?? this.id,
    title: title ?? this.title,
    createdAt: createdAt ?? this.createdAt,
    modifiedAt: modifiedAt ?? this.modifiedAt,
    isArchived: isArchived ?? this.isArchived,
  );
  MetronomePiece copyWithCompanion(MetronomePiecesCompanion data) {
    return MetronomePiece(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      modifiedAt: data.modifiedAt.present
          ? data.modifiedAt.value
          : this.modifiedAt,
      isArchived: data.isArchived.present
          ? data.isArchived.value
          : this.isArchived,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MetronomePiece(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('createdAt: $createdAt, ')
          ..write('modifiedAt: $modifiedAt, ')
          ..write('isArchived: $isArchived')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, title, createdAt, modifiedAt, isArchived);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MetronomePiece &&
          other.id == this.id &&
          other.title == this.title &&
          other.createdAt == this.createdAt &&
          other.modifiedAt == this.modifiedAt &&
          other.isArchived == this.isArchived);
}

class MetronomePiecesCompanion extends UpdateCompanion<MetronomePiece> {
  final Value<int> id;
  final Value<String> title;
  final Value<DateTime> createdAt;
  final Value<DateTime> modifiedAt;
  final Value<bool> isArchived;
  const MetronomePiecesCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.modifiedAt = const Value.absent(),
    this.isArchived = const Value.absent(),
  });
  MetronomePiecesCompanion.insert({
    this.id = const Value.absent(),
    required String title,
    required DateTime createdAt,
    required DateTime modifiedAt,
    this.isArchived = const Value.absent(),
  }) : title = Value(title),
       createdAt = Value(createdAt),
       modifiedAt = Value(modifiedAt);
  static Insertable<MetronomePiece> custom({
    Expression<int>? id,
    Expression<String>? title,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? modifiedAt,
    Expression<bool>? isArchived,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (createdAt != null) 'created_at': createdAt,
      if (modifiedAt != null) 'modified_at': modifiedAt,
      if (isArchived != null) 'is_archived': isArchived,
    });
  }

  MetronomePiecesCompanion copyWith({
    Value<int>? id,
    Value<String>? title,
    Value<DateTime>? createdAt,
    Value<DateTime>? modifiedAt,
    Value<bool>? isArchived,
  }) {
    return MetronomePiecesCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      modifiedAt: modifiedAt ?? this.modifiedAt,
      isArchived: isArchived ?? this.isArchived,
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
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (modifiedAt.present) {
      map['modified_at'] = Variable<DateTime>(modifiedAt.value);
    }
    if (isArchived.present) {
      map['is_archived'] = Variable<bool>(isArchived.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MetronomePiecesCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('createdAt: $createdAt, ')
          ..write('modifiedAt: $modifiedAt, ')
          ..write('isArchived: $isArchived')
          ..write(')'))
        .toString();
  }
}

class $PieceSectionsTable extends PieceSections
    with TableInfo<$PieceSectionsTable, PieceSection> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PieceSectionsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _pieceIdMeta = const VerificationMeta(
    'pieceId',
  );
  @override
  late final GeneratedColumn<int> pieceId = GeneratedColumn<int>(
    'piece_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
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
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startMeasureMeta = const VerificationMeta(
    'startMeasure',
  );
  @override
  late final GeneratedColumn<int> startMeasure = GeneratedColumn<int>(
    'start_measure',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endMeasureMeta = const VerificationMeta(
    'endMeasure',
  );
  @override
  late final GeneratedColumn<int> endMeasure = GeneratedColumn<int>(
    'end_measure',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bpmMeta = const VerificationMeta('bpm');
  @override
  late final GeneratedColumn<int> bpm = GeneratedColumn<int>(
    'bpm',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _timeSignatureMeta = const VerificationMeta(
    'timeSignature',
  );
  @override
  late final GeneratedColumn<String> timeSignature = GeneratedColumn<String>(
    'time_signature',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _subdivisionMeta = const VerificationMeta(
    'subdivision',
  );
  @override
  late final GeneratedColumn<String> subdivision = GeneratedColumn<String>(
    'subdivision',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _accentFirstBeatMeta = const VerificationMeta(
    'accentFirstBeat',
  );
  @override
  late final GeneratedColumn<bool> accentFirstBeat = GeneratedColumn<bool>(
    'accent_first_beat',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("accent_first_beat" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    pieceId,
    sortOrder,
    startMeasure,
    endMeasure,
    bpm,
    timeSignature,
    subdivision,
    accentFirstBeat,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'piece_sections';
  @override
  VerificationContext validateIntegrity(
    Insertable<PieceSection> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('piece_id')) {
      context.handle(
        _pieceIdMeta,
        pieceId.isAcceptableOrUnknown(data['piece_id']!, _pieceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_pieceIdMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    } else if (isInserting) {
      context.missing(_sortOrderMeta);
    }
    if (data.containsKey('start_measure')) {
      context.handle(
        _startMeasureMeta,
        startMeasure.isAcceptableOrUnknown(
          data['start_measure']!,
          _startMeasureMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_startMeasureMeta);
    }
    if (data.containsKey('end_measure')) {
      context.handle(
        _endMeasureMeta,
        endMeasure.isAcceptableOrUnknown(data['end_measure']!, _endMeasureMeta),
      );
    } else if (isInserting) {
      context.missing(_endMeasureMeta);
    }
    if (data.containsKey('bpm')) {
      context.handle(
        _bpmMeta,
        bpm.isAcceptableOrUnknown(data['bpm']!, _bpmMeta),
      );
    } else if (isInserting) {
      context.missing(_bpmMeta);
    }
    if (data.containsKey('time_signature')) {
      context.handle(
        _timeSignatureMeta,
        timeSignature.isAcceptableOrUnknown(
          data['time_signature']!,
          _timeSignatureMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_timeSignatureMeta);
    }
    if (data.containsKey('subdivision')) {
      context.handle(
        _subdivisionMeta,
        subdivision.isAcceptableOrUnknown(
          data['subdivision']!,
          _subdivisionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_subdivisionMeta);
    }
    if (data.containsKey('accent_first_beat')) {
      context.handle(
        _accentFirstBeatMeta,
        accentFirstBeat.isAcceptableOrUnknown(
          data['accent_first_beat']!,
          _accentFirstBeatMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PieceSection map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PieceSection(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      pieceId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}piece_id'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      startMeasure: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start_measure'],
      )!,
      endMeasure: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}end_measure'],
      )!,
      bpm: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}bpm'],
      )!,
      timeSignature: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}time_signature'],
      )!,
      subdivision: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subdivision'],
      )!,
      accentFirstBeat: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}accent_first_beat'],
      )!,
    );
  }

  @override
  $PieceSectionsTable createAlias(String alias) {
    return $PieceSectionsTable(attachedDatabase, alias);
  }
}

class PieceSection extends DataClass implements Insertable<PieceSection> {
  final int id;
  final int pieceId;
  final int sortOrder;
  final int startMeasure;
  final int endMeasure;
  final int bpm;
  final String timeSignature;
  final String subdivision;
  final bool accentFirstBeat;
  const PieceSection({
    required this.id,
    required this.pieceId,
    required this.sortOrder,
    required this.startMeasure,
    required this.endMeasure,
    required this.bpm,
    required this.timeSignature,
    required this.subdivision,
    required this.accentFirstBeat,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['piece_id'] = Variable<int>(pieceId);
    map['sort_order'] = Variable<int>(sortOrder);
    map['start_measure'] = Variable<int>(startMeasure);
    map['end_measure'] = Variable<int>(endMeasure);
    map['bpm'] = Variable<int>(bpm);
    map['time_signature'] = Variable<String>(timeSignature);
    map['subdivision'] = Variable<String>(subdivision);
    map['accent_first_beat'] = Variable<bool>(accentFirstBeat);
    return map;
  }

  PieceSectionsCompanion toCompanion(bool nullToAbsent) {
    return PieceSectionsCompanion(
      id: Value(id),
      pieceId: Value(pieceId),
      sortOrder: Value(sortOrder),
      startMeasure: Value(startMeasure),
      endMeasure: Value(endMeasure),
      bpm: Value(bpm),
      timeSignature: Value(timeSignature),
      subdivision: Value(subdivision),
      accentFirstBeat: Value(accentFirstBeat),
    );
  }

  factory PieceSection.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PieceSection(
      id: serializer.fromJson<int>(json['id']),
      pieceId: serializer.fromJson<int>(json['pieceId']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      startMeasure: serializer.fromJson<int>(json['startMeasure']),
      endMeasure: serializer.fromJson<int>(json['endMeasure']),
      bpm: serializer.fromJson<int>(json['bpm']),
      timeSignature: serializer.fromJson<String>(json['timeSignature']),
      subdivision: serializer.fromJson<String>(json['subdivision']),
      accentFirstBeat: serializer.fromJson<bool>(json['accentFirstBeat']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'pieceId': serializer.toJson<int>(pieceId),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'startMeasure': serializer.toJson<int>(startMeasure),
      'endMeasure': serializer.toJson<int>(endMeasure),
      'bpm': serializer.toJson<int>(bpm),
      'timeSignature': serializer.toJson<String>(timeSignature),
      'subdivision': serializer.toJson<String>(subdivision),
      'accentFirstBeat': serializer.toJson<bool>(accentFirstBeat),
    };
  }

  PieceSection copyWith({
    int? id,
    int? pieceId,
    int? sortOrder,
    int? startMeasure,
    int? endMeasure,
    int? bpm,
    String? timeSignature,
    String? subdivision,
    bool? accentFirstBeat,
  }) => PieceSection(
    id: id ?? this.id,
    pieceId: pieceId ?? this.pieceId,
    sortOrder: sortOrder ?? this.sortOrder,
    startMeasure: startMeasure ?? this.startMeasure,
    endMeasure: endMeasure ?? this.endMeasure,
    bpm: bpm ?? this.bpm,
    timeSignature: timeSignature ?? this.timeSignature,
    subdivision: subdivision ?? this.subdivision,
    accentFirstBeat: accentFirstBeat ?? this.accentFirstBeat,
  );
  PieceSection copyWithCompanion(PieceSectionsCompanion data) {
    return PieceSection(
      id: data.id.present ? data.id.value : this.id,
      pieceId: data.pieceId.present ? data.pieceId.value : this.pieceId,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      startMeasure: data.startMeasure.present
          ? data.startMeasure.value
          : this.startMeasure,
      endMeasure: data.endMeasure.present
          ? data.endMeasure.value
          : this.endMeasure,
      bpm: data.bpm.present ? data.bpm.value : this.bpm,
      timeSignature: data.timeSignature.present
          ? data.timeSignature.value
          : this.timeSignature,
      subdivision: data.subdivision.present
          ? data.subdivision.value
          : this.subdivision,
      accentFirstBeat: data.accentFirstBeat.present
          ? data.accentFirstBeat.value
          : this.accentFirstBeat,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PieceSection(')
          ..write('id: $id, ')
          ..write('pieceId: $pieceId, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('startMeasure: $startMeasure, ')
          ..write('endMeasure: $endMeasure, ')
          ..write('bpm: $bpm, ')
          ..write('timeSignature: $timeSignature, ')
          ..write('subdivision: $subdivision, ')
          ..write('accentFirstBeat: $accentFirstBeat')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    pieceId,
    sortOrder,
    startMeasure,
    endMeasure,
    bpm,
    timeSignature,
    subdivision,
    accentFirstBeat,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PieceSection &&
          other.id == this.id &&
          other.pieceId == this.pieceId &&
          other.sortOrder == this.sortOrder &&
          other.startMeasure == this.startMeasure &&
          other.endMeasure == this.endMeasure &&
          other.bpm == this.bpm &&
          other.timeSignature == this.timeSignature &&
          other.subdivision == this.subdivision &&
          other.accentFirstBeat == this.accentFirstBeat);
}

class PieceSectionsCompanion extends UpdateCompanion<PieceSection> {
  final Value<int> id;
  final Value<int> pieceId;
  final Value<int> sortOrder;
  final Value<int> startMeasure;
  final Value<int> endMeasure;
  final Value<int> bpm;
  final Value<String> timeSignature;
  final Value<String> subdivision;
  final Value<bool> accentFirstBeat;
  const PieceSectionsCompanion({
    this.id = const Value.absent(),
    this.pieceId = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.startMeasure = const Value.absent(),
    this.endMeasure = const Value.absent(),
    this.bpm = const Value.absent(),
    this.timeSignature = const Value.absent(),
    this.subdivision = const Value.absent(),
    this.accentFirstBeat = const Value.absent(),
  });
  PieceSectionsCompanion.insert({
    this.id = const Value.absent(),
    required int pieceId,
    required int sortOrder,
    required int startMeasure,
    required int endMeasure,
    required int bpm,
    required String timeSignature,
    required String subdivision,
    this.accentFirstBeat = const Value.absent(),
  }) : pieceId = Value(pieceId),
       sortOrder = Value(sortOrder),
       startMeasure = Value(startMeasure),
       endMeasure = Value(endMeasure),
       bpm = Value(bpm),
       timeSignature = Value(timeSignature),
       subdivision = Value(subdivision);
  static Insertable<PieceSection> custom({
    Expression<int>? id,
    Expression<int>? pieceId,
    Expression<int>? sortOrder,
    Expression<int>? startMeasure,
    Expression<int>? endMeasure,
    Expression<int>? bpm,
    Expression<String>? timeSignature,
    Expression<String>? subdivision,
    Expression<bool>? accentFirstBeat,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (pieceId != null) 'piece_id': pieceId,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (startMeasure != null) 'start_measure': startMeasure,
      if (endMeasure != null) 'end_measure': endMeasure,
      if (bpm != null) 'bpm': bpm,
      if (timeSignature != null) 'time_signature': timeSignature,
      if (subdivision != null) 'subdivision': subdivision,
      if (accentFirstBeat != null) 'accent_first_beat': accentFirstBeat,
    });
  }

  PieceSectionsCompanion copyWith({
    Value<int>? id,
    Value<int>? pieceId,
    Value<int>? sortOrder,
    Value<int>? startMeasure,
    Value<int>? endMeasure,
    Value<int>? bpm,
    Value<String>? timeSignature,
    Value<String>? subdivision,
    Value<bool>? accentFirstBeat,
  }) {
    return PieceSectionsCompanion(
      id: id ?? this.id,
      pieceId: pieceId ?? this.pieceId,
      sortOrder: sortOrder ?? this.sortOrder,
      startMeasure: startMeasure ?? this.startMeasure,
      endMeasure: endMeasure ?? this.endMeasure,
      bpm: bpm ?? this.bpm,
      timeSignature: timeSignature ?? this.timeSignature,
      subdivision: subdivision ?? this.subdivision,
      accentFirstBeat: accentFirstBeat ?? this.accentFirstBeat,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (pieceId.present) {
      map['piece_id'] = Variable<int>(pieceId.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (startMeasure.present) {
      map['start_measure'] = Variable<int>(startMeasure.value);
    }
    if (endMeasure.present) {
      map['end_measure'] = Variable<int>(endMeasure.value);
    }
    if (bpm.present) {
      map['bpm'] = Variable<int>(bpm.value);
    }
    if (timeSignature.present) {
      map['time_signature'] = Variable<String>(timeSignature.value);
    }
    if (subdivision.present) {
      map['subdivision'] = Variable<String>(subdivision.value);
    }
    if (accentFirstBeat.present) {
      map['accent_first_beat'] = Variable<bool>(accentFirstBeat.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PieceSectionsCompanion(')
          ..write('id: $id, ')
          ..write('pieceId: $pieceId, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('startMeasure: $startMeasure, ')
          ..write('endMeasure: $endMeasure, ')
          ..write('bpm: $bpm, ')
          ..write('timeSignature: $timeSignature, ')
          ..write('subdivision: $subdivision, ')
          ..write('accentFirstBeat: $accentFirstBeat')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $CategoriesTable categories = $CategoriesTable(this);
  late final $ExercisesTable exercises = $ExercisesTable(this);
  late final $BpmLogsTable bpmLogs = $BpmLogsTable(this);
  late final $ExerciseNotesTable exerciseNotes = $ExerciseNotesTable(this);
  late final $HistoryEntriesTable historyEntries = $HistoryEntriesTable(this);
  late final $ArchivedCategoryBundlesTable archivedCategoryBundles =
      $ArchivedCategoryBundlesTable(this);
  late final $CalendarEventsTable calendarEvents = $CalendarEventsTable(this);
  late final $EventRemindersTable eventReminders = $EventRemindersTable(this);
  late final $MetronomePiecesTable metronomePieces = $MetronomePiecesTable(
    this,
  );
  late final $PieceSectionsTable pieceSections = $PieceSectionsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    categories,
    exercises,
    bpmLogs,
    exerciseNotes,
    historyEntries,
    archivedCategoryBundles,
    calendarEvents,
    eventReminders,
    metronomePieces,
    pieceSections,
  ];
}

typedef $$CategoriesTableCreateCompanionBuilder =
    CategoriesCompanion Function({
      Value<int> id,
      required String name,
      required DateTime createdAt,
    });
typedef $$CategoriesTableUpdateCompanionBuilder =
    CategoriesCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<DateTime> createdAt,
    });

class $$CategoriesTableFilterComposer
    extends Composer<_$AppDatabase, $CategoriesTable> {
  $$CategoriesTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CategoriesTableOrderingComposer
    extends Composer<_$AppDatabase, $CategoriesTable> {
  $$CategoriesTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CategoriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CategoriesTable> {
  $$CategoriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$CategoriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CategoriesTable,
          Category,
          $$CategoriesTableFilterComposer,
          $$CategoriesTableOrderingComposer,
          $$CategoriesTableAnnotationComposer,
          $$CategoriesTableCreateCompanionBuilder,
          $$CategoriesTableUpdateCompanionBuilder,
          (Category, BaseReferences<_$AppDatabase, $CategoriesTable, Category>),
          Category,
          PrefetchHooks Function()
        > {
  $$CategoriesTableTableManager(_$AppDatabase db, $CategoriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CategoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CategoriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CategoriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) =>
                  CategoriesCompanion(id: id, name: name, createdAt: createdAt),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required DateTime createdAt,
              }) => CategoriesCompanion.insert(
                id: id,
                name: name,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CategoriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CategoriesTable,
      Category,
      $$CategoriesTableFilterComposer,
      $$CategoriesTableOrderingComposer,
      $$CategoriesTableAnnotationComposer,
      $$CategoriesTableCreateCompanionBuilder,
      $$CategoriesTableUpdateCompanionBuilder,
      (Category, BaseReferences<_$AppDatabase, $CategoriesTable, Category>),
      Category,
      PrefetchHooks Function()
    >;
typedef $$ExercisesTableCreateCompanionBuilder =
    ExercisesCompanion Function({
      Value<int> id,
      required String name,
      Value<int?> categoryId,
      Value<int> timesPracticed,
      Value<int> totalMinutes,
      Value<int> highestBpm,
      Value<int> lastBpm,
      Value<DateTime?> lastPracticed,
      Value<int> reminderDays,
      Value<int?> goalBpm,
      Value<int?> initialBpm,
      Value<bool> isArchived,
      Value<bool> archivedIndividually,
      Value<int?> archivedCategoryBundleId,
    });
typedef $$ExercisesTableUpdateCompanionBuilder =
    ExercisesCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<int?> categoryId,
      Value<int> timesPracticed,
      Value<int> totalMinutes,
      Value<int> highestBpm,
      Value<int> lastBpm,
      Value<DateTime?> lastPracticed,
      Value<int> reminderDays,
      Value<int?> goalBpm,
      Value<int?> initialBpm,
      Value<bool> isArchived,
      Value<bool> archivedIndividually,
      Value<int?> archivedCategoryBundleId,
    });

class $$ExercisesTableFilterComposer
    extends Composer<_$AppDatabase, $ExercisesTable> {
  $$ExercisesTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get timesPracticed => $composableBuilder(
    column: $table.timesPracticed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalMinutes => $composableBuilder(
    column: $table.totalMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get highestBpm => $composableBuilder(
    column: $table.highestBpm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastBpm => $composableBuilder(
    column: $table.lastBpm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastPracticed => $composableBuilder(
    column: $table.lastPracticed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get reminderDays => $composableBuilder(
    column: $table.reminderDays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get goalBpm => $composableBuilder(
    column: $table.goalBpm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get initialBpm => $composableBuilder(
    column: $table.initialBpm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get archivedIndividually => $composableBuilder(
    column: $table.archivedIndividually,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get archivedCategoryBundleId => $composableBuilder(
    column: $table.archivedCategoryBundleId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ExercisesTableOrderingComposer
    extends Composer<_$AppDatabase, $ExercisesTable> {
  $$ExercisesTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get timesPracticed => $composableBuilder(
    column: $table.timesPracticed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalMinutes => $composableBuilder(
    column: $table.totalMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get highestBpm => $composableBuilder(
    column: $table.highestBpm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastBpm => $composableBuilder(
    column: $table.lastBpm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastPracticed => $composableBuilder(
    column: $table.lastPracticed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get reminderDays => $composableBuilder(
    column: $table.reminderDays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get goalBpm => $composableBuilder(
    column: $table.goalBpm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get initialBpm => $composableBuilder(
    column: $table.initialBpm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get archivedIndividually => $composableBuilder(
    column: $table.archivedIndividually,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get archivedCategoryBundleId => $composableBuilder(
    column: $table.archivedCategoryBundleId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ExercisesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ExercisesTable> {
  $$ExercisesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get timesPracticed => $composableBuilder(
    column: $table.timesPracticed,
    builder: (column) => column,
  );

  GeneratedColumn<int> get totalMinutes => $composableBuilder(
    column: $table.totalMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get highestBpm => $composableBuilder(
    column: $table.highestBpm,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastBpm =>
      $composableBuilder(column: $table.lastBpm, builder: (column) => column);

  GeneratedColumn<DateTime> get lastPracticed => $composableBuilder(
    column: $table.lastPracticed,
    builder: (column) => column,
  );

  GeneratedColumn<int> get reminderDays => $composableBuilder(
    column: $table.reminderDays,
    builder: (column) => column,
  );

  GeneratedColumn<int> get goalBpm =>
      $composableBuilder(column: $table.goalBpm, builder: (column) => column);

  GeneratedColumn<int> get initialBpm => $composableBuilder(
    column: $table.initialBpm,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get archivedIndividually => $composableBuilder(
    column: $table.archivedIndividually,
    builder: (column) => column,
  );

  GeneratedColumn<int> get archivedCategoryBundleId => $composableBuilder(
    column: $table.archivedCategoryBundleId,
    builder: (column) => column,
  );
}

class $$ExercisesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ExercisesTable,
          Exercise,
          $$ExercisesTableFilterComposer,
          $$ExercisesTableOrderingComposer,
          $$ExercisesTableAnnotationComposer,
          $$ExercisesTableCreateCompanionBuilder,
          $$ExercisesTableUpdateCompanionBuilder,
          (Exercise, BaseReferences<_$AppDatabase, $ExercisesTable, Exercise>),
          Exercise,
          PrefetchHooks Function()
        > {
  $$ExercisesTableTableManager(_$AppDatabase db, $ExercisesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ExercisesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ExercisesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ExercisesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int?> categoryId = const Value.absent(),
                Value<int> timesPracticed = const Value.absent(),
                Value<int> totalMinutes = const Value.absent(),
                Value<int> highestBpm = const Value.absent(),
                Value<int> lastBpm = const Value.absent(),
                Value<DateTime?> lastPracticed = const Value.absent(),
                Value<int> reminderDays = const Value.absent(),
                Value<int?> goalBpm = const Value.absent(),
                Value<int?> initialBpm = const Value.absent(),
                Value<bool> isArchived = const Value.absent(),
                Value<bool> archivedIndividually = const Value.absent(),
                Value<int?> archivedCategoryBundleId = const Value.absent(),
              }) => ExercisesCompanion(
                id: id,
                name: name,
                categoryId: categoryId,
                timesPracticed: timesPracticed,
                totalMinutes: totalMinutes,
                highestBpm: highestBpm,
                lastBpm: lastBpm,
                lastPracticed: lastPracticed,
                reminderDays: reminderDays,
                goalBpm: goalBpm,
                initialBpm: initialBpm,
                isArchived: isArchived,
                archivedIndividually: archivedIndividually,
                archivedCategoryBundleId: archivedCategoryBundleId,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<int?> categoryId = const Value.absent(),
                Value<int> timesPracticed = const Value.absent(),
                Value<int> totalMinutes = const Value.absent(),
                Value<int> highestBpm = const Value.absent(),
                Value<int> lastBpm = const Value.absent(),
                Value<DateTime?> lastPracticed = const Value.absent(),
                Value<int> reminderDays = const Value.absent(),
                Value<int?> goalBpm = const Value.absent(),
                Value<int?> initialBpm = const Value.absent(),
                Value<bool> isArchived = const Value.absent(),
                Value<bool> archivedIndividually = const Value.absent(),
                Value<int?> archivedCategoryBundleId = const Value.absent(),
              }) => ExercisesCompanion.insert(
                id: id,
                name: name,
                categoryId: categoryId,
                timesPracticed: timesPracticed,
                totalMinutes: totalMinutes,
                highestBpm: highestBpm,
                lastBpm: lastBpm,
                lastPracticed: lastPracticed,
                reminderDays: reminderDays,
                goalBpm: goalBpm,
                initialBpm: initialBpm,
                isArchived: isArchived,
                archivedIndividually: archivedIndividually,
                archivedCategoryBundleId: archivedCategoryBundleId,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ExercisesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ExercisesTable,
      Exercise,
      $$ExercisesTableFilterComposer,
      $$ExercisesTableOrderingComposer,
      $$ExercisesTableAnnotationComposer,
      $$ExercisesTableCreateCompanionBuilder,
      $$ExercisesTableUpdateCompanionBuilder,
      (Exercise, BaseReferences<_$AppDatabase, $ExercisesTable, Exercise>),
      Exercise,
      PrefetchHooks Function()
    >;
typedef $$BpmLogsTableCreateCompanionBuilder =
    BpmLogsCompanion Function({
      Value<int> id,
      required int exerciseId,
      required int bpm,
      required DateTime loggedAt,
    });
typedef $$BpmLogsTableUpdateCompanionBuilder =
    BpmLogsCompanion Function({
      Value<int> id,
      Value<int> exerciseId,
      Value<int> bpm,
      Value<DateTime> loggedAt,
    });

class $$BpmLogsTableFilterComposer
    extends Composer<_$AppDatabase, $BpmLogsTable> {
  $$BpmLogsTableFilterComposer({
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

  ColumnFilters<int> get exerciseId => $composableBuilder(
    column: $table.exerciseId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get bpm => $composableBuilder(
    column: $table.bpm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get loggedAt => $composableBuilder(
    column: $table.loggedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BpmLogsTableOrderingComposer
    extends Composer<_$AppDatabase, $BpmLogsTable> {
  $$BpmLogsTableOrderingComposer({
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

  ColumnOrderings<int> get exerciseId => $composableBuilder(
    column: $table.exerciseId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get bpm => $composableBuilder(
    column: $table.bpm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get loggedAt => $composableBuilder(
    column: $table.loggedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BpmLogsTableAnnotationComposer
    extends Composer<_$AppDatabase, $BpmLogsTable> {
  $$BpmLogsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get exerciseId => $composableBuilder(
    column: $table.exerciseId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get bpm =>
      $composableBuilder(column: $table.bpm, builder: (column) => column);

  GeneratedColumn<DateTime> get loggedAt =>
      $composableBuilder(column: $table.loggedAt, builder: (column) => column);
}

class $$BpmLogsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BpmLogsTable,
          BpmLog,
          $$BpmLogsTableFilterComposer,
          $$BpmLogsTableOrderingComposer,
          $$BpmLogsTableAnnotationComposer,
          $$BpmLogsTableCreateCompanionBuilder,
          $$BpmLogsTableUpdateCompanionBuilder,
          (BpmLog, BaseReferences<_$AppDatabase, $BpmLogsTable, BpmLog>),
          BpmLog,
          PrefetchHooks Function()
        > {
  $$BpmLogsTableTableManager(_$AppDatabase db, $BpmLogsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BpmLogsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BpmLogsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BpmLogsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> exerciseId = const Value.absent(),
                Value<int> bpm = const Value.absent(),
                Value<DateTime> loggedAt = const Value.absent(),
              }) => BpmLogsCompanion(
                id: id,
                exerciseId: exerciseId,
                bpm: bpm,
                loggedAt: loggedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int exerciseId,
                required int bpm,
                required DateTime loggedAt,
              }) => BpmLogsCompanion.insert(
                id: id,
                exerciseId: exerciseId,
                bpm: bpm,
                loggedAt: loggedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BpmLogsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BpmLogsTable,
      BpmLog,
      $$BpmLogsTableFilterComposer,
      $$BpmLogsTableOrderingComposer,
      $$BpmLogsTableAnnotationComposer,
      $$BpmLogsTableCreateCompanionBuilder,
      $$BpmLogsTableUpdateCompanionBuilder,
      (BpmLog, BaseReferences<_$AppDatabase, $BpmLogsTable, BpmLog>),
      BpmLog,
      PrefetchHooks Function()
    >;
typedef $$ExerciseNotesTableCreateCompanionBuilder =
    ExerciseNotesCompanion Function({
      Value<int> id,
      required int exerciseId,
      required String noteText,
      required DateTime createdAt,
    });
typedef $$ExerciseNotesTableUpdateCompanionBuilder =
    ExerciseNotesCompanion Function({
      Value<int> id,
      Value<int> exerciseId,
      Value<String> noteText,
      Value<DateTime> createdAt,
    });

class $$ExerciseNotesTableFilterComposer
    extends Composer<_$AppDatabase, $ExerciseNotesTable> {
  $$ExerciseNotesTableFilterComposer({
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

  ColumnFilters<int> get exerciseId => $composableBuilder(
    column: $table.exerciseId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get noteText => $composableBuilder(
    column: $table.noteText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ExerciseNotesTableOrderingComposer
    extends Composer<_$AppDatabase, $ExerciseNotesTable> {
  $$ExerciseNotesTableOrderingComposer({
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

  ColumnOrderings<int> get exerciseId => $composableBuilder(
    column: $table.exerciseId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get noteText => $composableBuilder(
    column: $table.noteText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ExerciseNotesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ExerciseNotesTable> {
  $$ExerciseNotesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get exerciseId => $composableBuilder(
    column: $table.exerciseId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get noteText =>
      $composableBuilder(column: $table.noteText, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$ExerciseNotesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ExerciseNotesTable,
          ExerciseNote,
          $$ExerciseNotesTableFilterComposer,
          $$ExerciseNotesTableOrderingComposer,
          $$ExerciseNotesTableAnnotationComposer,
          $$ExerciseNotesTableCreateCompanionBuilder,
          $$ExerciseNotesTableUpdateCompanionBuilder,
          (
            ExerciseNote,
            BaseReferences<_$AppDatabase, $ExerciseNotesTable, ExerciseNote>,
          ),
          ExerciseNote,
          PrefetchHooks Function()
        > {
  $$ExerciseNotesTableTableManager(_$AppDatabase db, $ExerciseNotesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ExerciseNotesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ExerciseNotesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ExerciseNotesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> exerciseId = const Value.absent(),
                Value<String> noteText = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => ExerciseNotesCompanion(
                id: id,
                exerciseId: exerciseId,
                noteText: noteText,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int exerciseId,
                required String noteText,
                required DateTime createdAt,
              }) => ExerciseNotesCompanion.insert(
                id: id,
                exerciseId: exerciseId,
                noteText: noteText,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ExerciseNotesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ExerciseNotesTable,
      ExerciseNote,
      $$ExerciseNotesTableFilterComposer,
      $$ExerciseNotesTableOrderingComposer,
      $$ExerciseNotesTableAnnotationComposer,
      $$ExerciseNotesTableCreateCompanionBuilder,
      $$ExerciseNotesTableUpdateCompanionBuilder,
      (
        ExerciseNote,
        BaseReferences<_$AppDatabase, $ExerciseNotesTable, ExerciseNote>,
      ),
      ExerciseNote,
      PrefetchHooks Function()
    >;
typedef $$HistoryEntriesTableCreateCompanionBuilder =
    HistoryEntriesCompanion Function({
      Value<int> id,
      Value<int?> exerciseId,
      required String exerciseName,
      required DateTime date,
      required int minutes,
      required int bpm,
      Value<String> note,
    });
typedef $$HistoryEntriesTableUpdateCompanionBuilder =
    HistoryEntriesCompanion Function({
      Value<int> id,
      Value<int?> exerciseId,
      Value<String> exerciseName,
      Value<DateTime> date,
      Value<int> minutes,
      Value<int> bpm,
      Value<String> note,
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

  ColumnFilters<int> get exerciseId => $composableBuilder(
    column: $table.exerciseId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get exerciseName => $composableBuilder(
    column: $table.exerciseName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get minutes => $composableBuilder(
    column: $table.minutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get bpm => $composableBuilder(
    column: $table.bpm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
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

  ColumnOrderings<int> get exerciseId => $composableBuilder(
    column: $table.exerciseId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get exerciseName => $composableBuilder(
    column: $table.exerciseName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get minutes => $composableBuilder(
    column: $table.minutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get bpm => $composableBuilder(
    column: $table.bpm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
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

  GeneratedColumn<int> get exerciseId => $composableBuilder(
    column: $table.exerciseId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get exerciseName => $composableBuilder(
    column: $table.exerciseName,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<int> get minutes =>
      $composableBuilder(column: $table.minutes, builder: (column) => column);

  GeneratedColumn<int> get bpm =>
      $composableBuilder(column: $table.bpm, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);
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
                Value<int?> exerciseId = const Value.absent(),
                Value<String> exerciseName = const Value.absent(),
                Value<DateTime> date = const Value.absent(),
                Value<int> minutes = const Value.absent(),
                Value<int> bpm = const Value.absent(),
                Value<String> note = const Value.absent(),
              }) => HistoryEntriesCompanion(
                id: id,
                exerciseId: exerciseId,
                exerciseName: exerciseName,
                date: date,
                minutes: minutes,
                bpm: bpm,
                note: note,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> exerciseId = const Value.absent(),
                required String exerciseName,
                required DateTime date,
                required int minutes,
                required int bpm,
                Value<String> note = const Value.absent(),
              }) => HistoryEntriesCompanion.insert(
                id: id,
                exerciseId: exerciseId,
                exerciseName: exerciseName,
                date: date,
                minutes: minutes,
                bpm: bpm,
                note: note,
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
typedef $$ArchivedCategoryBundlesTableCreateCompanionBuilder =
    ArchivedCategoryBundlesCompanion Function({
      Value<int> id,
      required String name,
      required DateTime archivedAt,
    });
typedef $$ArchivedCategoryBundlesTableUpdateCompanionBuilder =
    ArchivedCategoryBundlesCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<DateTime> archivedAt,
    });

class $$ArchivedCategoryBundlesTableFilterComposer
    extends Composer<_$AppDatabase, $ArchivedCategoryBundlesTable> {
  $$ArchivedCategoryBundlesTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ArchivedCategoryBundlesTableOrderingComposer
    extends Composer<_$AppDatabase, $ArchivedCategoryBundlesTable> {
  $$ArchivedCategoryBundlesTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ArchivedCategoryBundlesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ArchivedCategoryBundlesTable> {
  $$ArchivedCategoryBundlesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => column,
  );
}

class $$ArchivedCategoryBundlesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ArchivedCategoryBundlesTable,
          ArchivedCategoryBundle,
          $$ArchivedCategoryBundlesTableFilterComposer,
          $$ArchivedCategoryBundlesTableOrderingComposer,
          $$ArchivedCategoryBundlesTableAnnotationComposer,
          $$ArchivedCategoryBundlesTableCreateCompanionBuilder,
          $$ArchivedCategoryBundlesTableUpdateCompanionBuilder,
          (
            ArchivedCategoryBundle,
            BaseReferences<
              _$AppDatabase,
              $ArchivedCategoryBundlesTable,
              ArchivedCategoryBundle
            >,
          ),
          ArchivedCategoryBundle,
          PrefetchHooks Function()
        > {
  $$ArchivedCategoryBundlesTableTableManager(
    _$AppDatabase db,
    $ArchivedCategoryBundlesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ArchivedCategoryBundlesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$ArchivedCategoryBundlesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$ArchivedCategoryBundlesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<DateTime> archivedAt = const Value.absent(),
              }) => ArchivedCategoryBundlesCompanion(
                id: id,
                name: name,
                archivedAt: archivedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required DateTime archivedAt,
              }) => ArchivedCategoryBundlesCompanion.insert(
                id: id,
                name: name,
                archivedAt: archivedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ArchivedCategoryBundlesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ArchivedCategoryBundlesTable,
      ArchivedCategoryBundle,
      $$ArchivedCategoryBundlesTableFilterComposer,
      $$ArchivedCategoryBundlesTableOrderingComposer,
      $$ArchivedCategoryBundlesTableAnnotationComposer,
      $$ArchivedCategoryBundlesTableCreateCompanionBuilder,
      $$ArchivedCategoryBundlesTableUpdateCompanionBuilder,
      (
        ArchivedCategoryBundle,
        BaseReferences<
          _$AppDatabase,
          $ArchivedCategoryBundlesTable,
          ArchivedCategoryBundle
        >,
      ),
      ArchivedCategoryBundle,
      PrefetchHooks Function()
    >;
typedef $$CalendarEventsTableCreateCompanionBuilder =
    CalendarEventsCompanion Function({
      Value<int> id,
      required String title,
      Value<String> notes,
      required DateTime startDate,
      required DateTime endDate,
      Value<int?> colorValue,
      required DateTime createdAt,
    });
typedef $$CalendarEventsTableUpdateCompanionBuilder =
    CalendarEventsCompanion Function({
      Value<int> id,
      Value<String> title,
      Value<String> notes,
      Value<DateTime> startDate,
      Value<DateTime> endDate,
      Value<int?> colorValue,
      Value<DateTime> createdAt,
    });

class $$CalendarEventsTableFilterComposer
    extends Composer<_$AppDatabase, $CalendarEventsTable> {
  $$CalendarEventsTableFilterComposer({
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

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get endDate => $composableBuilder(
    column: $table.endDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get colorValue => $composableBuilder(
    column: $table.colorValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CalendarEventsTableOrderingComposer
    extends Composer<_$AppDatabase, $CalendarEventsTable> {
  $$CalendarEventsTableOrderingComposer({
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

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get endDate => $composableBuilder(
    column: $table.endDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get colorValue => $composableBuilder(
    column: $table.colorValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CalendarEventsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CalendarEventsTable> {
  $$CalendarEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<DateTime> get startDate =>
      $composableBuilder(column: $table.startDate, builder: (column) => column);

  GeneratedColumn<DateTime> get endDate =>
      $composableBuilder(column: $table.endDate, builder: (column) => column);

  GeneratedColumn<int> get colorValue => $composableBuilder(
    column: $table.colorValue,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$CalendarEventsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CalendarEventsTable,
          CalendarEvent,
          $$CalendarEventsTableFilterComposer,
          $$CalendarEventsTableOrderingComposer,
          $$CalendarEventsTableAnnotationComposer,
          $$CalendarEventsTableCreateCompanionBuilder,
          $$CalendarEventsTableUpdateCompanionBuilder,
          (
            CalendarEvent,
            BaseReferences<_$AppDatabase, $CalendarEventsTable, CalendarEvent>,
          ),
          CalendarEvent,
          PrefetchHooks Function()
        > {
  $$CalendarEventsTableTableManager(
    _$AppDatabase db,
    $CalendarEventsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CalendarEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CalendarEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CalendarEventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> notes = const Value.absent(),
                Value<DateTime> startDate = const Value.absent(),
                Value<DateTime> endDate = const Value.absent(),
                Value<int?> colorValue = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => CalendarEventsCompanion(
                id: id,
                title: title,
                notes: notes,
                startDate: startDate,
                endDate: endDate,
                colorValue: colorValue,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String title,
                Value<String> notes = const Value.absent(),
                required DateTime startDate,
                required DateTime endDate,
                Value<int?> colorValue = const Value.absent(),
                required DateTime createdAt,
              }) => CalendarEventsCompanion.insert(
                id: id,
                title: title,
                notes: notes,
                startDate: startDate,
                endDate: endDate,
                colorValue: colorValue,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CalendarEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CalendarEventsTable,
      CalendarEvent,
      $$CalendarEventsTableFilterComposer,
      $$CalendarEventsTableOrderingComposer,
      $$CalendarEventsTableAnnotationComposer,
      $$CalendarEventsTableCreateCompanionBuilder,
      $$CalendarEventsTableUpdateCompanionBuilder,
      (
        CalendarEvent,
        BaseReferences<_$AppDatabase, $CalendarEventsTable, CalendarEvent>,
      ),
      CalendarEvent,
      PrefetchHooks Function()
    >;
typedef $$EventRemindersTableCreateCompanionBuilder =
    EventRemindersCompanion Function({
      Value<int> id,
      required int eventId,
      required int daysBefore,
      Value<DateTime?> customDate,
    });
typedef $$EventRemindersTableUpdateCompanionBuilder =
    EventRemindersCompanion Function({
      Value<int> id,
      Value<int> eventId,
      Value<int> daysBefore,
      Value<DateTime?> customDate,
    });

class $$EventRemindersTableFilterComposer
    extends Composer<_$AppDatabase, $EventRemindersTable> {
  $$EventRemindersTableFilterComposer({
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

  ColumnFilters<int> get eventId => $composableBuilder(
    column: $table.eventId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get daysBefore => $composableBuilder(
    column: $table.daysBefore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get customDate => $composableBuilder(
    column: $table.customDate,
    builder: (column) => ColumnFilters(column),
  );
}

class $$EventRemindersTableOrderingComposer
    extends Composer<_$AppDatabase, $EventRemindersTable> {
  $$EventRemindersTableOrderingComposer({
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

  ColumnOrderings<int> get eventId => $composableBuilder(
    column: $table.eventId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get daysBefore => $composableBuilder(
    column: $table.daysBefore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get customDate => $composableBuilder(
    column: $table.customDate,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$EventRemindersTableAnnotationComposer
    extends Composer<_$AppDatabase, $EventRemindersTable> {
  $$EventRemindersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get eventId =>
      $composableBuilder(column: $table.eventId, builder: (column) => column);

  GeneratedColumn<int> get daysBefore => $composableBuilder(
    column: $table.daysBefore,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get customDate => $composableBuilder(
    column: $table.customDate,
    builder: (column) => column,
  );
}

class $$EventRemindersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EventRemindersTable,
          EventReminder,
          $$EventRemindersTableFilterComposer,
          $$EventRemindersTableOrderingComposer,
          $$EventRemindersTableAnnotationComposer,
          $$EventRemindersTableCreateCompanionBuilder,
          $$EventRemindersTableUpdateCompanionBuilder,
          (
            EventReminder,
            BaseReferences<_$AppDatabase, $EventRemindersTable, EventReminder>,
          ),
          EventReminder,
          PrefetchHooks Function()
        > {
  $$EventRemindersTableTableManager(
    _$AppDatabase db,
    $EventRemindersTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EventRemindersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EventRemindersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EventRemindersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> eventId = const Value.absent(),
                Value<int> daysBefore = const Value.absent(),
                Value<DateTime?> customDate = const Value.absent(),
              }) => EventRemindersCompanion(
                id: id,
                eventId: eventId,
                daysBefore: daysBefore,
                customDate: customDate,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int eventId,
                required int daysBefore,
                Value<DateTime?> customDate = const Value.absent(),
              }) => EventRemindersCompanion.insert(
                id: id,
                eventId: eventId,
                daysBefore: daysBefore,
                customDate: customDate,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$EventRemindersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EventRemindersTable,
      EventReminder,
      $$EventRemindersTableFilterComposer,
      $$EventRemindersTableOrderingComposer,
      $$EventRemindersTableAnnotationComposer,
      $$EventRemindersTableCreateCompanionBuilder,
      $$EventRemindersTableUpdateCompanionBuilder,
      (
        EventReminder,
        BaseReferences<_$AppDatabase, $EventRemindersTable, EventReminder>,
      ),
      EventReminder,
      PrefetchHooks Function()
    >;
typedef $$MetronomePiecesTableCreateCompanionBuilder =
    MetronomePiecesCompanion Function({
      Value<int> id,
      required String title,
      required DateTime createdAt,
      required DateTime modifiedAt,
      Value<bool> isArchived,
    });
typedef $$MetronomePiecesTableUpdateCompanionBuilder =
    MetronomePiecesCompanion Function({
      Value<int> id,
      Value<String> title,
      Value<DateTime> createdAt,
      Value<DateTime> modifiedAt,
      Value<bool> isArchived,
    });

class $$MetronomePiecesTableFilterComposer
    extends Composer<_$AppDatabase, $MetronomePiecesTable> {
  $$MetronomePiecesTableFilterComposer({
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

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get modifiedAt => $composableBuilder(
    column: $table.modifiedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MetronomePiecesTableOrderingComposer
    extends Composer<_$AppDatabase, $MetronomePiecesTable> {
  $$MetronomePiecesTableOrderingComposer({
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

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get modifiedAt => $composableBuilder(
    column: $table.modifiedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MetronomePiecesTableAnnotationComposer
    extends Composer<_$AppDatabase, $MetronomePiecesTable> {
  $$MetronomePiecesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get modifiedAt => $composableBuilder(
    column: $table.modifiedAt,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => column,
  );
}

class $$MetronomePiecesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MetronomePiecesTable,
          MetronomePiece,
          $$MetronomePiecesTableFilterComposer,
          $$MetronomePiecesTableOrderingComposer,
          $$MetronomePiecesTableAnnotationComposer,
          $$MetronomePiecesTableCreateCompanionBuilder,
          $$MetronomePiecesTableUpdateCompanionBuilder,
          (
            MetronomePiece,
            BaseReferences<
              _$AppDatabase,
              $MetronomePiecesTable,
              MetronomePiece
            >,
          ),
          MetronomePiece,
          PrefetchHooks Function()
        > {
  $$MetronomePiecesTableTableManager(
    _$AppDatabase db,
    $MetronomePiecesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MetronomePiecesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MetronomePiecesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MetronomePiecesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> modifiedAt = const Value.absent(),
                Value<bool> isArchived = const Value.absent(),
              }) => MetronomePiecesCompanion(
                id: id,
                title: title,
                createdAt: createdAt,
                modifiedAt: modifiedAt,
                isArchived: isArchived,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String title,
                required DateTime createdAt,
                required DateTime modifiedAt,
                Value<bool> isArchived = const Value.absent(),
              }) => MetronomePiecesCompanion.insert(
                id: id,
                title: title,
                createdAt: createdAt,
                modifiedAt: modifiedAt,
                isArchived: isArchived,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MetronomePiecesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MetronomePiecesTable,
      MetronomePiece,
      $$MetronomePiecesTableFilterComposer,
      $$MetronomePiecesTableOrderingComposer,
      $$MetronomePiecesTableAnnotationComposer,
      $$MetronomePiecesTableCreateCompanionBuilder,
      $$MetronomePiecesTableUpdateCompanionBuilder,
      (
        MetronomePiece,
        BaseReferences<_$AppDatabase, $MetronomePiecesTable, MetronomePiece>,
      ),
      MetronomePiece,
      PrefetchHooks Function()
    >;
typedef $$PieceSectionsTableCreateCompanionBuilder =
    PieceSectionsCompanion Function({
      Value<int> id,
      required int pieceId,
      required int sortOrder,
      required int startMeasure,
      required int endMeasure,
      required int bpm,
      required String timeSignature,
      required String subdivision,
      Value<bool> accentFirstBeat,
    });
typedef $$PieceSectionsTableUpdateCompanionBuilder =
    PieceSectionsCompanion Function({
      Value<int> id,
      Value<int> pieceId,
      Value<int> sortOrder,
      Value<int> startMeasure,
      Value<int> endMeasure,
      Value<int> bpm,
      Value<String> timeSignature,
      Value<String> subdivision,
      Value<bool> accentFirstBeat,
    });

class $$PieceSectionsTableFilterComposer
    extends Composer<_$AppDatabase, $PieceSectionsTable> {
  $$PieceSectionsTableFilterComposer({
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

  ColumnFilters<int> get pieceId => $composableBuilder(
    column: $table.pieceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startMeasure => $composableBuilder(
    column: $table.startMeasure,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endMeasure => $composableBuilder(
    column: $table.endMeasure,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get bpm => $composableBuilder(
    column: $table.bpm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get timeSignature => $composableBuilder(
    column: $table.timeSignature,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subdivision => $composableBuilder(
    column: $table.subdivision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get accentFirstBeat => $composableBuilder(
    column: $table.accentFirstBeat,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PieceSectionsTableOrderingComposer
    extends Composer<_$AppDatabase, $PieceSectionsTable> {
  $$PieceSectionsTableOrderingComposer({
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

  ColumnOrderings<int> get pieceId => $composableBuilder(
    column: $table.pieceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startMeasure => $composableBuilder(
    column: $table.startMeasure,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endMeasure => $composableBuilder(
    column: $table.endMeasure,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get bpm => $composableBuilder(
    column: $table.bpm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get timeSignature => $composableBuilder(
    column: $table.timeSignature,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subdivision => $composableBuilder(
    column: $table.subdivision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get accentFirstBeat => $composableBuilder(
    column: $table.accentFirstBeat,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PieceSectionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PieceSectionsTable> {
  $$PieceSectionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get pieceId =>
      $composableBuilder(column: $table.pieceId, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<int> get startMeasure => $composableBuilder(
    column: $table.startMeasure,
    builder: (column) => column,
  );

  GeneratedColumn<int> get endMeasure => $composableBuilder(
    column: $table.endMeasure,
    builder: (column) => column,
  );

  GeneratedColumn<int> get bpm =>
      $composableBuilder(column: $table.bpm, builder: (column) => column);

  GeneratedColumn<String> get timeSignature => $composableBuilder(
    column: $table.timeSignature,
    builder: (column) => column,
  );

  GeneratedColumn<String> get subdivision => $composableBuilder(
    column: $table.subdivision,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get accentFirstBeat => $composableBuilder(
    column: $table.accentFirstBeat,
    builder: (column) => column,
  );
}

class $$PieceSectionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PieceSectionsTable,
          PieceSection,
          $$PieceSectionsTableFilterComposer,
          $$PieceSectionsTableOrderingComposer,
          $$PieceSectionsTableAnnotationComposer,
          $$PieceSectionsTableCreateCompanionBuilder,
          $$PieceSectionsTableUpdateCompanionBuilder,
          (
            PieceSection,
            BaseReferences<_$AppDatabase, $PieceSectionsTable, PieceSection>,
          ),
          PieceSection,
          PrefetchHooks Function()
        > {
  $$PieceSectionsTableTableManager(_$AppDatabase db, $PieceSectionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PieceSectionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PieceSectionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PieceSectionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> pieceId = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> startMeasure = const Value.absent(),
                Value<int> endMeasure = const Value.absent(),
                Value<int> bpm = const Value.absent(),
                Value<String> timeSignature = const Value.absent(),
                Value<String> subdivision = const Value.absent(),
                Value<bool> accentFirstBeat = const Value.absent(),
              }) => PieceSectionsCompanion(
                id: id,
                pieceId: pieceId,
                sortOrder: sortOrder,
                startMeasure: startMeasure,
                endMeasure: endMeasure,
                bpm: bpm,
                timeSignature: timeSignature,
                subdivision: subdivision,
                accentFirstBeat: accentFirstBeat,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int pieceId,
                required int sortOrder,
                required int startMeasure,
                required int endMeasure,
                required int bpm,
                required String timeSignature,
                required String subdivision,
                Value<bool> accentFirstBeat = const Value.absent(),
              }) => PieceSectionsCompanion.insert(
                id: id,
                pieceId: pieceId,
                sortOrder: sortOrder,
                startMeasure: startMeasure,
                endMeasure: endMeasure,
                bpm: bpm,
                timeSignature: timeSignature,
                subdivision: subdivision,
                accentFirstBeat: accentFirstBeat,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PieceSectionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PieceSectionsTable,
      PieceSection,
      $$PieceSectionsTableFilterComposer,
      $$PieceSectionsTableOrderingComposer,
      $$PieceSectionsTableAnnotationComposer,
      $$PieceSectionsTableCreateCompanionBuilder,
      $$PieceSectionsTableUpdateCompanionBuilder,
      (
        PieceSection,
        BaseReferences<_$AppDatabase, $PieceSectionsTable, PieceSection>,
      ),
      PieceSection,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$CategoriesTableTableManager get categories =>
      $$CategoriesTableTableManager(_db, _db.categories);
  $$ExercisesTableTableManager get exercises =>
      $$ExercisesTableTableManager(_db, _db.exercises);
  $$BpmLogsTableTableManager get bpmLogs =>
      $$BpmLogsTableTableManager(_db, _db.bpmLogs);
  $$ExerciseNotesTableTableManager get exerciseNotes =>
      $$ExerciseNotesTableTableManager(_db, _db.exerciseNotes);
  $$HistoryEntriesTableTableManager get historyEntries =>
      $$HistoryEntriesTableTableManager(_db, _db.historyEntries);
  $$ArchivedCategoryBundlesTableTableManager get archivedCategoryBundles =>
      $$ArchivedCategoryBundlesTableTableManager(
        _db,
        _db.archivedCategoryBundles,
      );
  $$CalendarEventsTableTableManager get calendarEvents =>
      $$CalendarEventsTableTableManager(_db, _db.calendarEvents);
  $$EventRemindersTableTableManager get eventReminders =>
      $$EventRemindersTableTableManager(_db, _db.eventReminders);
  $$MetronomePiecesTableTableManager get metronomePieces =>
      $$MetronomePiecesTableTableManager(_db, _db.metronomePieces);
  $$PieceSectionsTableTableManager get pieceSections =>
      $$PieceSectionsTableTableManager(_db, _db.pieceSections);
}
