import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:zfjw_toolkit/core/model/course_record.dart';
import 'package:zfjw_toolkit/core/model/snapshot.dart';

part 'database.g.dart';

/// 学生档案表。当前单档案，但存储按多档案设计。
@DataClassName('ProfileRow')
class Profiles extends Table {
  /// 文本 uuid 主键。
  TextColumn get id => text()();

  /// 档案名称。
  TextColumn get name => text()();

  /// 档案创建时间。
  DateTimeColumn get createdAt => dateTime()();

  /// 规则包标识，默认内置徐医规则包。
  TextColumn get rulePreset => text().withDefault(const Constant('xzhmu'))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// 成绩快照表。档案可持有多个快照（多来源、多时间采集）。
@DataClassName('SnapshotRow')
class Snapshots extends Table {
  /// 快照主键。
  TextColumn get id => text()();

  /// 所属档案外键。
  TextColumn get profileId => text().references(Profiles, #id)();

  /// 采集来源（webview/file/manual）。
  TextColumn get source => text().map(const SnapshotSourceConverter())();

  /// 采集时间戳。
  DateTimeColumn get capturedAt => dateTime()();

  /// 完整成绩记录列表（`List<CourseRecord>` 序列化后的 JSON）。
  TextColumn get records => text().map(const CourseRecordListConverter())();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// [SnapshotSource] 与存储字符串（枚举名）之间的转换。
class SnapshotSourceConverter extends TypeConverter<SnapshotSource, String> {
  const SnapshotSourceConverter();

  @override
  SnapshotSource fromSql(String fromDb) =>
      SnapshotSource.values.firstWhere((e) => e.name == fromDb,
          orElse: () => SnapshotSource.webview);

  @override
  String toSql(SnapshotSource value) => value.name;
}

/// [CourseRecord] 与 JSON 之间的转换（[core/model] 未提供 toJson，
/// 序列化逻辑集中在 data 层，避免改动核心模型）。
Map<String, dynamic> courseRecordToJson(CourseRecord r) => {
      'kch': r.kch,
      'kcmc': r.kcmc,
      'xf': r.xf,
      'jd': r.jd,
      'bfzcj': r.bfzcj,
      'cj': r.cj,
      'cjbz': r.cjbz,
      'sfxwkc': r.sfxwkc,
      'xnm': r.xnm,
      'xqm': r.xqm,
      'xnmmc': r.xnmmc,
      'xqmmc': r.xqmmc,
    };

/// [List<CourseRecord>] 与存储 JSON 字符串之间的转换。
class CourseRecordListConverter
    extends TypeConverter<List<CourseRecord>, String> {
  const CourseRecordListConverter();

  @override
  List<CourseRecord> fromSql(String fromDb) =>
      (jsonDecode(fromDb) as List<dynamic>)
          .map((e) => CourseRecord.fromJson(e as Map<String, dynamic>))
          .toList();

  @override
  String toSql(List<CourseRecord> value) =>
      jsonEncode(value.map(courseRecordToJson).toList());
}

/// 应用持久化数据库（drift）。
@DriftDatabase(tables: [Profiles, Snapshots])
class AppDatabase extends _$AppDatabase {
  /// 使用指定执行器构造（测试可注入 [NativeDatabase.memory]）。
  AppDatabase(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async => m.createAll(),
      );
}
