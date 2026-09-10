import '../model/teaching_plan.dart';
import 'result_types.dart';

/// 目标分析范围：全部课程 / 仅学位课。
enum TargetScope { all, degree }

/// 某一范围（全部课程或学位课）下的目标达成分析结果。
class TargetAnalysis {
  const TargetAnalysis({
    required this.scope,
    required this.completedCredits,
    required this.remainingCredits,
    required this.remainingCourseCount,
    required this.basisCredits,
    required this.currentGpa,
    required this.requiredRemainingGpa,
    required this.planScopeIdentified,
  });

  final TargetScope scope;

  /// 范围内已修学分（全部课程 = 有效记录总学分；学位课 = 学位课总学分）。
  final double completedCredits;

  /// 范围内剩余学分（全部课程 = 计划毕业学分 − 已修；学位课 = 未通过的计划学位课学分之和）。
  final double remainingCredits;

  /// 剩余学分对应的未通过计划课程门数（全部课程范围不涉及，置 0）。
  final int remainingCourseCount;

  /// 最终总学分基准：全部课程 = 计划毕业学分；学位课 = 已修 + 剩余。
  final double basisCredits;

  /// 范围内当前 GPA（无有效绩点数据时为 null）。
  final double? currentGpa;

  /// 剩余课程达到目标所需的最低平均绩点；无剩余学分或基准为 0 时为 null。
  final double? requiredRemainingGpa;

  /// 学位课范围专用：教学计划中是否识别到学位课。false 时剩余学分被低估，
  /// 界面应提示「计划未标记学位课」。
  final bool planScopeIdentified;

  /// 假设剩余课程平均绩点为 [remainingGpa] 时的最终 GPA 投影。
  double project(double remainingGpa) => basisCredits == 0
      ? (currentGpa ?? 0)
      : ((currentGpa ?? 0) * completedCredits +
              remainingGpa * remainingCredits) /
          basisCredits;
}

/// 按范围做目标达成分析。
///
/// 全部课程：沿用「计划毕业学分 − 已修学分」口径。
/// 学位课：计划课程按 sfxwkc 标记或匹配已修学位课记录识别为学位课，
/// 剩余学分 = 识别出的学位课中尚无通过记录的学分之和。
TargetAnalysis analyzeTarget({
  required StatsResult stats,
  required TeachingPlan plan,
  required double targetGpa,
  required TargetScope scope,
}) {
  if (scope == TargetScope.all) return _analyzeAll(stats, plan, targetGpa);
  return _analyzeDegree(stats, plan, targetGpa);
}

TargetAnalysis _analyzeAll(StatsResult stats, TeachingPlan plan, double targetGpa) {
  final completed = stats.overall.totalCredits;
  final remaining =
      (plan.graduationCredits - completed).clamp(0, double.infinity).toDouble();
  final currentGpa = stats.overall.gpa;
  final basis = plan.graduationCredits;
  return TargetAnalysis(
    scope: TargetScope.all,
    completedCredits: completed,
    remainingCredits: remaining,
    remainingCourseCount: 0,
    basisCredits: basis,
    currentGpa: currentGpa,
    requiredRemainingGpa: remaining == 0 || basis == 0
        ? null
        : (targetGpa * basis - (currentGpa ?? 0) * completed) / remaining,
    planScopeIdentified: true,
  );
}

/// 判定计划课程是否为学位课：计划自带 sfxwkc 标记，
/// 或匹配到已修学位课记录（按课程键/课程名）。
bool isDegreePlannedCourse(StatsResult stats, PlannedCourse c) {
  if (c.sfxwkc.contains('是')) return true;
  final key = plannedCourseKey(c);
  for (final r in stats.rows) {
    if (stats.preset.isDegreeCourse(r) &&
        (r.courseKey == key || (c.name.isNotEmpty && r.kcmc == c.name))) {
      return true;
    }
  }
  return false;
}

TargetAnalysis _analyzeDegree(
    StatsResult stats, TeachingPlan plan, double targetGpa) {
  final preset = stats.preset;

  bool hasPassingRecord(PlannedCourse c) {
    final key = plannedCourseKey(c);
    for (final r in stats.rows) {
      if ((r.courseKey == key || (c.name.isNotEmpty && r.kcmc == c.name)) &&
          preset.isPass(r)) {
        return true;
      }
    }
    return false;
  }

  final degreeCourses =
      plan.courses.where((c) => isDegreePlannedCourse(stats, c)).toList();
  final remainingCourses =
      degreeCourses.where((c) => !hasPassingRecord(c)).toList();
  final remaining =
      remainingCourses.fold(0.0, (sum, c) => sum + c.credits);
  final completed = stats.degree.totalCredits;
  final currentGpa = stats.degree.gpa;
  final basis = completed + remaining;
  return TargetAnalysis(
    scope: TargetScope.degree,
    completedCredits: completed,
    remainingCredits: remaining,
    remainingCourseCount: remainingCourses.length,
    basisCredits: basis,
    currentGpa: currentGpa,
    requiredRemainingGpa: remaining == 0 || basis == 0
        ? null
        : (targetGpa * basis - (currentGpa ?? 0) * completed) / remaining,
    planScopeIdentified: degreeCourses.isNotEmpty,
  );
}
