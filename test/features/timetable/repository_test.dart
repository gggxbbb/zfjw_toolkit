import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:zfjw_toolkit/data/database.dart' hide TimetableTerm;
import 'package:zfjw_toolkit/features/timetable/model.dart';
import 'package:zfjw_toolkit/features/timetable/repository.dart';

void main() {
  final monday = DateTime(2026, 9, 7);
  const s = ClassSession(name: '课程', week: 2, day: 1, start: 1, end: 2);
  test('快照去重、历史保留、多学期隔离、空版本与设置独立', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = TimetableRepository(db);
    const capture = TimetableCapture('2026/3', '2026第一学期', [s]);
    expect(await repo.accept(capture, monday, 20), isTrue);
    expect(await repo.accept(capture, monday, 20), isFalse);
    expect(await repo.history(capture.term), hasLength(1));
    await repo.accept(
      const TimetableCapture('2026/12', '2026第二学期', [s]),
      monday,
      20,
    );
    expect(await repo.terms(), hasLength(2));
    await repo.accept(
      const TimetableCapture('2026/3', '2026第一学期', []),
      monday,
      20,
    );
    final history = await repo.history(capture.term);
    expect(history, hasLength(2));
    expect(history.first.sessions, isEmpty);
    expect(history.last.sessions.single.name, '课程');
    final term = (await repo.terms()).firstWhere((t) => t.id == capture.term);
    await repo.settings(term, DateTime(2026, 9, 14), 22);
    expect((await repo.history(capture.term)).length, 2);
    expect(
      (await repo.terms()).firstWhere((t) => t.id == capture.term).weeks,
      22,
    );
  });
  test('无效设置导致整个事务不写入', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = TimetableRepository(db);
    await expectLater(
      repo.accept(const TimetableCapture('t', '学期', [s]), monday, 1),
      throwsArgumentError,
    );
    expect(await repo.terms(), isEmpty);
    expect(await repo.history('t'), isEmpty);
  });
  test('v1数据库升级到v2保留原档案和成绩快照', () async {
    final dir = await Directory.systemTemp.createTemp('timetable_migration_');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/old.sqlite');
    final old = sqlite.sqlite3.open(file.path);
    old.execute(
      'CREATE TABLE profiles (id TEXT PRIMARY KEY, name TEXT NOT NULL, created_at INTEGER NOT NULL, rule_preset TEXT NOT NULL DEFAULT \'xzhmu\')',
    );
    old.execute(
      'CREATE TABLE snapshots (id TEXT PRIMARY KEY, profile_id TEXT NOT NULL REFERENCES profiles(id), source TEXT NOT NULL, captured_at INTEGER NOT NULL, records TEXT NOT NULL)',
    );
    old.execute("INSERT INTO profiles VALUES ('p', '保留档案', 1, 'xzhmu')");
    old.execute("INSERT INTO snapshots VALUES ('s', 'p', 'webview', 1, '[]')");
    old.execute('PRAGMA user_version = 1');
    old.dispose();
    final db = AppDatabase(NativeDatabase(file));
    try {
      expect((await db.select(db.profiles).get()).single.name, '保留档案');
      expect((await db.select(db.snapshots).get()).single.id, 's');
      final repo = TimetableRepository(db);
      expect(
        await repo.accept(const TimetableCapture('t', '学期', [s]), monday, 20),
        isTrue,
      );
    } finally {
      await db.close();
    }
  });
}
