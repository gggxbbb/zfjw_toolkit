import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zfjw_toolkit/core/model/course_record.dart';
import 'package:zfjw_toolkit/core/model/snapshot.dart';
import 'package:zfjw_toolkit/data/database.dart';
import 'package:zfjw_toolkit/data/snapshot_repository.dart';
import 'package:zfjw_toolkit/features/gpa/state/gpa_providers.dart';
import 'package:zfjw_toolkit/features/manage/data_management_page.dart';

Widget _wrap(Widget child, {required AppDatabase db}) => ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: CupertinoApp(home: child),
    );

List<CourseRecord> _sampleRecords() => [
      CourseRecord.fromRaw(
        kch: 'A01', kcmc: '高等数学', xf: '4', jd: '4.0',
        bfzcj: '90', cj: '90', sfxwkc: '是',
        xnm: '2024', xqm: '1', xnmmc: '2024-2025', xqmmc: '1',
      ),
      CourseRecord.fromRaw(
        kch: 'A02', kcmc: '大学英语', xf: '2', jd: '3.0',
        bfzcj: '80', cj: '80', sfxwkc: '否',
        xnm: '2024', xqm: '1', xnmmc: '2024-2025', xqmmc: '1',
      ),
    ];

void _seedRecordOverrides(Map<String, dynamic> json) {
  SharedPreferences.setMockInitialValues(
      {'record_overrides': jsonEncode(json)});
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DataManagementPage（成绩记录）', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      final repo = SnapshotRepository(db);
      final profile = await repo.ensureDefaultProfile();
      await repo.saveSnapshot(
          profile.id, SnapshotSource.webview, _sampleRecords());
    });

    tearDown(() async => db.close());

    testWidgets('默认列出全部采集记录', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(_wrap(const DataManagementPage(), db: db));
      await tester.pumpAndSettle();

      expect(find.text('高等数学'), findsOneWidget);
      expect(find.text('大学英语'), findsOneWidget);
      expect(find.textContaining('已删除'), findsNothing);
    });

    testWidgets('删除补丁隐藏记录并出现在已删除区（可恢复）', (tester) async {
      _seedRecordOverrides({
        'patches': [
          {'courseKey': 'A01', 'xnm': '2024', 'xqm': '1', 'deleted': true},
        ],
        'additions': [],
      });
      await tester.pumpWidget(_wrap(const DataManagementPage(), db: db));
      await tester.pumpAndSettle();

      // 被删除的记录不在主列表，但在底部「已删除」区可见并可恢复。
      expect(find.text('大学英语'), findsOneWidget);
      expect(find.textContaining('已删除的记录'), findsOneWidget);
      expect(find.textContaining('高等数学（'), findsOneWidget);
      expect(find.text('恢复'), findsOneWidget);
    });

    testWidgets('修改补丁覆盖展示值并带「已修改」徽标', (tester) async {
      _seedRecordOverrides({
        'patches': [
          {'courseKey': 'A01', 'xnm': '2024', 'xqm': '1', 'bfzcj': '95'},
        ],
        'additions': [],
      });
      await tester.pumpWidget(_wrap(const DataManagementPage(), db: db));
      await tester.pumpAndSettle();

      expect(find.textContaining('已修改'), findsOneWidget);
      expect(find.textContaining('成绩 95'), findsOneWidget);
      // 未覆盖字段保留采集值（学分 4 仍在）。
      expect(find.textContaining('学分 4'), findsWidgets);
    });

    testWidgets('手动新增记录与采集记录并列展示', (tester) async {
      _seedRecordOverrides({
        'patches': [],
        'additions': [
          {
            'kch': 'M01',
            'kcmc': '校外课程',
            'xf': '2',
            'bfzcj': '88',
            'cj': '88',
            'sfxwkc': '否',
            'xnm': '2025',
            'xqm': '1',
            'xnmmc': '2025-2026',
            'xqmmc': '1',
          },
        ],
      });
      await tester.pumpWidget(_wrap(const DataManagementPage(), db: db));
      await tester.pumpAndSettle();

      expect(find.text('校外课程'), findsOneWidget);
      expect(find.textContaining('新增 ·'), findsOneWidget);
      // 采集记录不受影响。
      expect(find.text('高等数学'), findsOneWidget);
    });
  });
}
