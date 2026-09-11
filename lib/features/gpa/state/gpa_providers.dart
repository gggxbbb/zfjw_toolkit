import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift_flutter/drift_flutter.dart' as drift_flutter;

import 'package:zfjw_toolkit/core/model/course_record.dart';
import 'package:zfjw_toolkit/core/model/overrides.dart';
import 'package:zfjw_toolkit/core/rules/presets/xzhmu.dart';
import 'package:zfjw_toolkit/core/stats/stats_engine.dart';
import 'package:zfjw_toolkit/core/stats/result_types.dart';
import 'package:zfjw_toolkit/core/model/snapshot.dart';
import 'package:zfjw_toolkit/data/database.dart';
import 'package:zfjw_toolkit/data/override_repository.dart';
import 'package:zfjw_toolkit/data/snapshot_repository.dart';

/// 应用级数据库实例（drift）。生产环境走原生 SQLite（移动端），
/// 测试可通过 override 注入 [AppDatabase(NativeDatabase.memory())]。
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase(drift_flutter.driftDatabase(
    name: 'zfjw_toolkit',
    native: drift_flutter.DriftNativeOptions(),
  ));
  ref.onDispose(db.close);
  return db;
});

/// 快照仓储单例。
final snapshotRepositoryProvider = Provider<SnapshotRepository>(
  (ref) => SnapshotRepository(ref.watch(databaseProvider)),
);

/// 当前档案的最新成绩快照；null 表示尚未采集任何数据。
final latestSnapshotProvider = FutureProvider<Snapshot?>((ref) async {
  final repo = ref.watch(snapshotRepositoryProvider);
  final profile = await repo.ensureDefaultProfile();
  return repo.latestSnapshot(profile.id);
});

/// 徐医规则包单例（v1 唯一 preset；未来从 profile.rulePreset 解析）。
final rulePresetProvider = Provider<XzhmuRulePreset>(
  (ref) => const XzhmuRulePreset(),
);

/// 用户编辑（override）仓储单例。
final overrideRepositoryProvider = Provider<OverrideRepository>(
  (ref) => OverrideRepository(),
);

/// 成绩 overrides：补丁（修改/删除采集记录）+ 手动新增记录。
///
/// 独立于快照存储，重新采集后自动再次应用。
final recordOverridesProvider =
    AsyncNotifierProvider<RecordOverridesNotifier, RecordOverrides>(
  RecordOverridesNotifier.new,
);

class RecordOverridesNotifier extends AsyncNotifier<RecordOverrides> {
  OverrideRepository get _repo => ref.read(overrideRepositoryProvider);

  @override
  Future<RecordOverrides> build() => _repo.loadRecords();

  Future<void> _save(RecordOverrides next) async {
    state = AsyncData(next);
    await _repo.saveRecords(next);
  }

  /// 保存对一条采集记录的修改；与原始值相同的字段应在 [patch] 中保持 null。
  Future<void> upsertPatch(RecordPatch patch) =>
      _save((state.value ?? const RecordOverrides()).upsertPatch(patch));

  /// 撤销对一条采集记录的修改/删除（恢复采集值）。
  Future<void> removePatch(String courseKey, String xnm, String xqm) =>
      _save((state.value ?? const RecordOverrides())
          .removePatch(courseKey, xnm, xqm));

  /// 新增/替换一条手动成绩记录（同课程同学期后写覆盖）。
  Future<void> upsertAddition(CourseRecord record) =>
      _save((state.value ?? const RecordOverrides()).upsertAddition(record));

  /// 删除一条手动成绩记录。
  Future<void> removeAddition(String courseKey, String xnm, String xqm) =>
      _save((state.value ?? const RecordOverrides())
          .removeAddition(courseKey, xnm, xqm));
}

/// 应用 overrides 后的有效成绩记录；统计与目标分析统一走这里。
/// 无快照且无手动新增时为 null（空态）。
final effectiveRecordsProvider = FutureProvider<List<CourseRecord>?>(
  (ref) async {
    final snapshot = await ref.watch(latestSnapshotProvider.future);
    final overrides = await ref.watch(recordOverridesProvider.future);
    if (snapshot == null && overrides.additions.isEmpty) return null;
    return applyRecordOverrides(snapshot?.records ?? const [], overrides);
  },
);

/// 统计结果：有效记录 → 规则包 → computeStats。无数据时为 null。
final statsProvider = FutureProvider<StatsResult?>((ref) async {
  final records = await ref.watch(effectiveRecordsProvider.future);
  if (records == null || records.isEmpty) return null;
  return computeStats(records, ref.watch(rulePresetProvider));
});
