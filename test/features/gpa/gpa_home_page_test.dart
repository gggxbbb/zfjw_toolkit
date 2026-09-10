import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zfjw_toolkit/core/model/course_record.dart';
import 'package:zfjw_toolkit/core/model/snapshot.dart';
import 'package:zfjw_toolkit/data/database.dart';
import 'package:zfjw_toolkit/data/snapshot_repository.dart';
import 'package:zfjw_toolkit/features/gpa/gpa_home_page.dart';
import 'package:zfjw_toolkit/features/gpa/state/gpa_providers.dart';
import 'package:zfjw_toolkit/ui/kit/kit.dart';

/// 页面依赖主壳传入的大标题控制器；测试里造一个并负责释放。
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

void main() {
  group('GpaHomePage', () {
    late AppDatabase db;
    late GlassLargeTitleController title;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      title = GlassLargeTitleController();
    });

    tearDown(() async {
      title.dispose();
      await db.close();
    });

    testWidgets('无快照时显示空态引导', (tester) async {
      await tester.pumpWidget(
        _wrap(GpaHomePage(titleController: title), db: db),
      );
      await tester.pumpAndSettle();

      expect(find.text('暂无成绩数据'), findsOneWidget);
      expect(find.text('去采集'), findsOneWidget);
      expect(find.text('导入 HTML'), findsOneWidget);
    });

    testWidgets('有快照时显示统计分区', (tester) async {
      final repo = SnapshotRepository(db);
      final profile = await repo.ensureDefaultProfile();
      await repo.saveSnapshot(
        profile.id,
        SnapshotSource.webview,
        _sampleRecords(),
      );

      await tester.pumpWidget(
        _wrap(GpaHomePage(titleController: title), db: db),
      );
      await tester.pumpAndSettle();

      // 总览：4 学分绩点 4.0 + 2 学分绩点 3.0 → GPA = (16+6)/6 ≈ 3.67
      expect(find.text('3.67'), findsOneWidget);
      // 「学位 GPA」出现在总览行与 What-If 对比行两处
      expect(find.text('学位 GPA'), findsNWidgets(2));
      expect(find.text('假设分析'), findsOneWidget);
      expect(find.text('各学期（1 个）'), findsOneWidget);
      // 懒加载：滚屏外的分区用 skipOffstage:false 查找
      expect(find.text('成绩分布', skipOffstage: false), findsOneWidget);
      // 有数据时不再显示空态引导
      expect(find.text('暂无成绩数据'), findsNothing);
    });
  });
}
