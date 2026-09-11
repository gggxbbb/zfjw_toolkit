import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zfjw_toolkit/core/model/overrides.dart';
import 'package:zfjw_toolkit/core/model/teaching_plan.dart';
import 'package:zfjw_toolkit/data/override_repository.dart';
import 'package:zfjw_toolkit/data/teaching_plan_repository.dart';
import 'package:zfjw_toolkit/features/gpa/state/gpa_providers.dart';

/// 最近一次采集的教学计划（原始值，不含用户编辑）。
final teachingPlanProvider =
    FutureProvider((ref) => TeachingPlanRepository().load());

/// 教学计划 overrides：计划信息覆盖 + 课程补丁 + 手动新增课程。
///
/// 独立于采集数据存储，重新采集后自动再次应用。
final planOverridesProvider =
    AsyncNotifierProvider<PlanOverridesNotifier, PlanOverrides>(
  PlanOverridesNotifier.new,
);

class PlanOverridesNotifier extends AsyncNotifier<PlanOverrides> {
  OverrideRepository get _repo => ref.read(overrideRepositoryProvider);

  @override
  Future<PlanOverrides> build() => _repo.loadPlan();

  Future<void> _save(PlanOverrides next) async {
    state = AsyncData(next);
    await _repo.savePlan(next);
  }

  /// 覆盖计划名称 / 毕业学分要求；传 null 恢复采集值。
  Future<void> setPlanInfo({String? programName, double? graduationCredits}) =>
      _save((state.value ?? const PlanOverrides()).copyWithPlanInfo(
        programName: () => programName,
        graduationCredits: () => graduationCredits,
      ));

  /// 保存对一门采集课程的修改；与原始值相同的字段应在 [patch] 中保持 null。
  Future<void> upsertPatch(PlanCoursePatch patch) =>
      _save((state.value ?? const PlanOverrides()).upsertPatch(patch));

  /// 撤销对一门采集课程的修改/删除（恢复采集值）。
  Future<void> removePatch(String key) =>
      _save((state.value ?? const PlanOverrides()).removePatch(key));

  /// 新增/替换一门手动计划课程（同键后写覆盖）。
  Future<void> upsertAddition(PlannedCourse course) =>
      _save((state.value ?? const PlanOverrides()).upsertAddition(course));

  /// 删除一门手动计划课程。
  Future<void> removeAddition(String key) =>
      _save((state.value ?? const PlanOverrides()).removeAddition(key));
}

/// 应用 overrides 后的有效教学计划；目标分析与 What-If 统一走这里。
/// 未采集且无手动新增时为 null（空态）。
final effectiveTeachingPlanProvider = FutureProvider<TeachingPlan?>(
  (ref) async {
    final raw = await ref.watch(teachingPlanProvider.future);
    final overrides = await ref.watch(planOverridesProvider.future);
    if (raw == null) {
      if (overrides.isEmpty) return null;
      return applyPlanOverrides(
        const TeachingPlan(programName: '', graduationCredits: 0, courses: []),
        overrides,
      );
    }
    return applyPlanOverrides(raw, overrides);
  },
);
