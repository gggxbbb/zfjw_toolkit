import 'dart:convert';
import 'dart:typed_data';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zfjw_toolkit/app/theme.dart';
import 'package:zfjw_toolkit/core/model/course_record.dart';
import 'package:zfjw_toolkit/core/model/overrides.dart';
import 'package:zfjw_toolkit/core/model/snapshot.dart';
import 'package:zfjw_toolkit/data/database.dart';
import 'package:zfjw_toolkit/data/override_repository.dart';
import 'package:zfjw_toolkit/data/snapshot_repository.dart';
import 'package:zfjw_toolkit/features/backup/backup_document.dart';
import 'package:zfjw_toolkit/features/backup/backup_page.dart';
import 'package:zfjw_toolkit/features/backup/document_gateway.dart';
import 'package:zfjw_toolkit/features/backup/providers.dart';
import 'package:zfjw_toolkit/features/gpa/state/gpa_providers.dart';
import 'package:zfjw_toolkit/features/settings/settings_home_page.dart';
import 'package:zfjw_toolkit/features/settings/state/app_version.dart';
import 'package:zfjw_toolkit/ui/kit/kit.dart';
import 'backup_service_test.dart' show fixture;

class FakeDocuments implements DocumentGateway {
  String? input;
  bool saved = true, failSave = false;
  final outputs = <Uint8List>[];
  @override
  Future<String?> openBackup() async => input;
  @override
  Future<bool> save(String name, Uint8List bytes, String mimeType) async {
    if (failSave) throw StateError('无法写入文件');
    if (saved) outputs.add(bytes);
    return saved;
  }
}

void main() {
  late AppDatabase db;
  late FakeDocuments documents;
  late ProviderContainer container;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase(NativeDatabase.memory());
    documents = FakeDocuments();
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        documentGatewayProvider.overrideWithValue(documents),
        appVersionProvider.overrideWith((ref) async => 'test'),
      ],
    );
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<void> pump(
    WidgetTester tester, {
    bool dark = false,
    double width = 390,
    Widget? home,
  }) async {
    tester.view.physicalSize = Size(width, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: dark ? ThemeMode.dark : ThemeMode.light,
          home: home ?? const BackupPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String label) async {
    await tester.ensureVisible(find.text(label).last);
    await tester.pump();
    await tester.runAsync(() async {
      await tester.tap(find.text(label).last);
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    // A confirmation intentionally keeps the operation busy underneath it.
    // Do not wait for that progress animation to stop before answering it.
    await tester.pump(const Duration(milliseconds: 500));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> seed(WidgetTester tester) async {
    await tester.runAsync(() async {
      final repo = SnapshotRepository(db);
      await repo.ensureDefaultProfile();
      await repo.saveSnapshot(kDefaultProfileId, SnapshotSource.webview, [
        const CourseRecord(kch: '001', kcmc: '课程', cj: '80', xf: '2'),
      ]);
      await OverrideRepository().saveRecords(
        const RecordOverrides(
          patches: [RecordPatch(courseKey: '001', cj: '95')],
        ),
      );
    });
  }

  testWidgets('settings opens the data hub', (tester) async {
    final controller = GlassLargeTitleController();
    addTearDown(controller.dispose);
    await pump(tester, home: SettingsHomePage(titleController: controller));
    await tap(tester, '数据与备份');
    expect(find.text('导入完整备份'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final width in [390.0, 1200.0]) {
    for (final dark in [false, true]) {
      testWidgets(
        'hub and import preview fit $width dark=$dark; cancel writes nothing',
        (tester) async {
          documents.input = fixture().encode();
          await pump(tester, width: width, dark: dark);
          expect(tester.takeException(), isNull);
          await tap(tester, '导入完整备份');
          expect(find.text('导入预览'), findsOneWidget);
          expect(find.textContaining('成绩快照：3'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tap(tester, '取消导入');
          final rows = await tester.runAsync(
            () => db.select(db.snapshots).get(),
          );
          expect(rows, isEmpty);
        },
      );
    }
  }

  testWidgets(
    'JSON export confirms, saves a complete backup and handles cancellation/failure',
    (tester) async {
      await seed(tester);
      await pump(tester);
      await tap(tester, '导出完整备份');
      await tap(tester, '取消');
      expect(documents.outputs, isEmpty);
      await tap(tester, '导出完整备份');
      await tap(tester, '选择保存位置');
      expect(find.text('文件已保存'), findsOneWidget);
      expect(
        BackupDocument.parse(
          utf8.decode(documents.outputs.single),
        ).rows('snapshots'),
        hasLength(1),
      );
      documents.saved = false;
      await tap(tester, '导出完整备份');
      await tap(tester, '选择保存位置');
      expect(find.text('已取消保存'), findsOneWidget);
      documents.failSave = true;
      await tap(tester, '导出完整备份');
      await tap(tester, '选择保存位置');
      expect(find.textContaining('无法写入文件'), findsOneWidget);
    },
  );

  testWidgets(
    'current CSV applies changes while historical CSV keeps raw data',
    (tester) async {
      await seed(tester);
      await pump(tester);
      await tap(tester, '导出当前成绩');
      await tap(tester, '选择保存位置');
      expect(utf8.decode(documents.outputs.last), contains('"95"'));
      await tap(tester, '导出历史成绩');
      await tap(tester, '导出此快照');
      await tap(tester, '选择保存位置');
      expect(utf8.decode(documents.outputs.last), contains('"80"'));
      expect(utf8.decode(documents.outputs.last), isNot(contains('"95"')));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'replacement requires second confirmation and refreshes loaded grades',
    (tester) async {
      await seed(tester);
      final before = await tester.runAsync(
        () => container.read(effectiveRecordsProvider.future),
      );
      expect(before!.single.cj, '95');
      final incoming = fixture();
      incoming.rows('profiles').single['id'] = kDefaultProfileId;
      for (final s in incoming.rows('snapshots')) {
        s['profileId'] = kDefaultProfileId;
      }
      incoming.preferences['record_overrides'] = null;
      documents.input = incoming.encode();
      await pump(tester);
      await tap(tester, '导入完整备份');
      expect(find.textContaining('无法合并'), findsOneWidget);
      await tap(tester, '替换本机数据');
      await tap(tester, '取消');
      expect(
        (await tester.runAsync(() => db.select(db.snapshots).get()))!,
        hasLength(1),
      );
      await tap(tester, '替换本机数据');
      await tap(tester, '确认替换');
      expect(find.text('已完成替换恢复'), findsOneWidget);
      final after = await tester.runAsync(
        () => container.read(effectiveRecordsProvider.future),
      );
      expect(after!.single.cj, '优秀');
    },
  );

  testWidgets('cancel file selection and malformed backup never modify data', (
    tester,
  ) async {
    await seed(tester);
    await pump(tester);
    await tap(tester, '导入完整备份');
    expect(find.text('导入预览'), findsNothing);
    documents.input = '{broken';
    await tap(tester, '导入完整备份');
    expect(find.textContaining('操作失败'), findsOneWidget);
    expect(
      (await tester.runAsync(() => db.select(db.snapshots).get()))!,
      hasLength(1),
    );
  });
}
