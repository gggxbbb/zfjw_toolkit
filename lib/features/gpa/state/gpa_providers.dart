import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift_flutter/drift_flutter.dart' as drift_flutter;

import 'package:zfjw_toolkit/core/rules/presets/xzhmu.dart';
import 'package:zfjw_toolkit/core/stats/stats_engine.dart';
import 'package:zfjw_toolkit/core/stats/result_types.dart';
import 'package:zfjw_toolkit/core/model/snapshot.dart';
import 'package:zfjw_toolkit/data/database.dart';
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

/// 统计结果：快照 → 规则包 → computeStats。无快照时为 null。
final statsProvider = FutureProvider<StatsResult?>((ref) async {
  final snapshot = await ref.watch(latestSnapshotProvider.future);
  if (snapshot == null || snapshot.records.isEmpty) return null;
  return computeStats(snapshot.records, ref.watch(rulePresetProvider));
});
