import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zfjw_toolkit/core/model/course_record.dart';
import 'package:zfjw_toolkit/core/model/snapshot.dart';
import 'package:zfjw_toolkit/data/database.dart';
import 'package:zfjw_toolkit/data/snapshot_repository.dart';

/// 构造一组含空字段的成绩记录，用于验证序列化往返无损。
List<CourseRecord> sampleRecords() => [
      CourseRecord.fromRaw(
        kch: 'A001',
        kcmc: '高等数学',
        xf: '3.0',
        jd: '4.0',
        bfzcj: '90',
        cj: '90',
        sfxwkc: '是',
        xnm: '2023',
        xqm: '1',
        xnmmc: '2023-2024 学年',
        xqmmc: '1',
      ),
      CourseRecord.fromRaw(
        kch: 'A002',
        kcmc: '大学英语',
        xf: '2.0',
        jd: null,
        bfzcj: null,
        cj: '良好',
        sfxwkc: '否',
      ),
    ];

AppDatabase newMemoryDb() => AppDatabase(NativeDatabase.memory());

void main() {
  group('SnapshotRepository', () {
    late AppDatabase db;
    late SnapshotRepository repo;

    setUp(() {
      db = newMemoryDb();
      repo = SnapshotRepository(db);
    });

    tearDown(() => db.close());

    test('ensureDefaultProfile 幂等：重复调用只创建一条档案', () async {
      final first = await repo.ensureDefaultProfile();
      final second = await repo.ensureDefaultProfile();

      expect(first.id, second.id);
      final all =
          await db.select(db.profiles).get();
      expect(all.length, 1);
      expect(all.single.id, first.id);
    });

    test('saveSnapshot + listSnapshots 往返无损', () async {
      final profile = await repo.ensureDefaultProfile();
      final saved = await repo.saveSnapshot(
        profile.id,
        SnapshotSource.webview,
        sampleRecords(),
      );

      final listed = await repo.listSnapshots(profile.id);
      expect(listed.length, 1);

      final snap = listed.single;
      expect(snap.id, saved.id);
      expect(snap.source, SnapshotSource.webview);
      expect(snap.records.length, 2);
      // 字段往返无损（含 null 字段）。
      expect(snap.records, sampleRecords());
    });

    test('listSnapshots 按采集时间倒序返回', () async {
      final profile = await repo.ensureDefaultProfile();
      final a = await repo.saveSnapshot(
          profile.id, SnapshotSource.webview, [CourseRecord.fromRaw(kch: 'K1')]);
      // 让采集时间戳严格递增，验证按时间倒序。
      await Future.delayed(const Duration(seconds: 1));
      final b = await repo.saveSnapshot(
          profile.id, SnapshotSource.file, [CourseRecord.fromRaw(kch: 'K2')]);

      final listed = await repo.listSnapshots(profile.id);
      expect(listed.map((s) => s.id), [b.id, a.id]);
    });

    test('latestSnapshot 空档案返回 null', () async {
      final profile = await repo.ensureDefaultProfile();
      expect(await repo.latestSnapshot(profile.id), isNull);
    });

    test('latestSnapshot 非空返回最新快照', () async {
      final profile = await repo.ensureDefaultProfile();
      await repo.saveSnapshot(
          profile.id, SnapshotSource.webview, [CourseRecord.fromRaw(kch: 'K1')]);
      await Future.delayed(const Duration(seconds: 1));
      final newer = await repo.saveSnapshot(
          profile.id, SnapshotSource.manual, [CourseRecord.fromRaw(kch: 'K2')]);

      final latest = await repo.latestSnapshot(profile.id);
      expect(latest, isNotNull);
      expect(latest!.id, newer.id);
      expect(latest.source, SnapshotSource.manual);
    });
  });
}
