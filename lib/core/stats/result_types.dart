import '../model/course_record.dart';
import '../rules/rule_preset.dart';

/// 统计结果的数据类集合（纯 Dart，无 Flutter 依赖）。
///
/// 字段可空语义对齐油猴脚本 `jwpt-gpa.user.js`：
/// `gpa` 为 `null` 表示无有效绩点数据，`weightedAvg`/`arithAvg` 同理。

/// 五档分数分布标签，顺序与 [AggregateResult.distribution] 一致。
const List<String> distributionLabels = [
  '90-100',
  '80-89',
  '70-79',
  '60-69',
  '<60',
];

/// 单组统计结果：一组课程记录聚合出的各项指标。
class AggregateResult {
  /// 该组记录条数（含非百分制记录）。
  final int count;

  /// GPA = Σ(xf·jd) / Σxf，仅统计有有效绩点且学分的课；无有效数据时为 null。
  final double? gpa;

  /// 加权平均分 = Σ(xf·score) / Σxf；无有效分数时为 null。
  final double? weightedAvg;

  /// 算术平均分 = Σscore / n；无有效分数时为 null。
  final double? arithAvg;

  /// 已获学分：通过判定的记录学分之和。
  final double earnedCredits;

  /// 已修学分：所有有学分记录之和。
  final double totalCredits;

  /// 不及格门数（去重后仍未通过的记录数）。
  final int failCount;

  /// 非百分制（无有效分数）门数。
  final int nonNumeric;

  /// 最高分（带课程名）。
  final double? maxScore;
  final String? maxCourse;

  /// 最低分（带课程名）。
  final double? minScore;
  final String? minCourse;

  /// 五档分数分布：[90-100, 80-89, 70-79, 60-69, <60] 各档计数。
  final List<int> distribution;

  const AggregateResult({
    required this.count,
    this.gpa,
    this.weightedAvg,
    this.arithAvg,
    required this.earnedCredits,
    required this.totalCredits,
    required this.failCount,
    required this.nonNumeric,
    this.maxScore,
    this.maxCourse,
    this.minScore,
    this.minCourse,
    required this.distribution,
  });

  @override
  String toString() =>
      'AggregateResult(count: $count, gpa: $gpa, weightedAvg: $weightedAvg, '
      'arithAvg: $arithAvg, earnedCredits: $earnedCredits, '
      'totalCredits: $totalCredits, failCount: $failCount, '
      'nonNumeric: $nonNumeric, max: $maxScore($maxCourse), '
      'min: $minScore($minCourse), distribution: $distribution)';
}

/// 单学期统计：学期分组后的 GPA / 学分 / 门数。
class SemesterStat {
  /// 排序键：`xnmmc + ' 第' + xqmmc + '学期'`。
  final String key;

  /// 排序值：`xnm*100 + xqm`。
  final int sort;

  final double? gpa;
  final double credits;
  final int count;

  const SemesterStat({
    required this.key,
    required this.sort,
    this.gpa,
    required this.credits,
    required this.count,
  });

  @override
  String toString() =>
      'SemesterStat(key: $key, sort: $sort, gpa: $gpa, '
      'credits: $credits, count: $count)';
}

/// 挂科项：去重取最高分后仍不及格的记录。
class FailingItem {
  final String? name;
  final double? credit;
  final double? score;
  final String semester;

  const FailingItem({
    this.name,
    this.credit,
    this.score,
    required this.semester,
  });

  @override
  String toString() =>
      'FailingItem(name: $name, credit: $credit, score: $score, '
      'semester: $semester)';
}

/// 疑似误输入项：百分制成绩 < 10 分。
class SuspiciousItem {
  final String? name;
  final double score;
  final String semester;

  const SuspiciousItem({
    this.name,
    required this.score,
    required this.semester,
  });

  @override
  String toString() =>
      'SuspiciousItem(name: $name, score: $score, semester: $semester)';
}

/// 免修明细项。
class ExemptItem {
  final String? name;
  final double? credit;
  final String semester;

  const ExemptItem({
    this.name,
    this.credit,
    required this.semester,
  });

  @override
  String toString() =>
      'ExemptItem(name: $name, credit: $credit, semester: $semester)';
}

/// 免修汇总：免修不参与任何成绩统计，学分单独展示。
class ExemptSummary {
  final int count;
  final double credits;
  final List<ExemptItem> list;

  const ExemptSummary({
    required this.count,
    required this.credits,
    required this.list,
  });

  @override
  String toString() =>
      'ExemptSummary(count: $count, credits: $credits, list: ${list.length})';
}

/// 完整统计结果。
class StatsResult {
  /// 原始记录条数（含重修/补考，未去重）。
  final int attempts;

  /// 总体统计（免修已剥离）。
  final AggregateResult overall;

  /// 学位课子集统计。
  final AggregateResult degree;

  /// 学期分组（按排序值升序）。
  final List<SemesterStat> semesters;

  /// 挂科列表。
  final List<FailingItem> failing;

  /// 疑似误输入列表。
  final List<SuspiciousItem> suspicious;

  /// 免修汇总。
  final ExemptSummary exempt;

  /// 有效（去重且非免修）记录集，供 What-If 重算使用。
  final List<CourseRecord> rows;

  /// 计算所用规则包，供 What-If 重估绩点使用。
  final RulePreset preset;

  const StatsResult({
    required this.attempts,
    required this.overall,
    required this.degree,
    required this.semesters,
    required this.failing,
    required this.suspicious,
    required this.exempt,
    required this.rows,
    required this.preset,
  });

  @override
  String toString() =>
      'StatsResult(attempts: $attempts, overall: $overall, degree: $degree, '
      'semesters: ${semesters.length}, failing: ${failing.length}, '
      'suspicious: ${suspicious.length}, exempt: $exempt, rows: ${rows.length})';
}

/// What-If 模拟结果：假设某课分数替换前后的总体与学位聚合对比。
class SimulateResult {
  final AggregateResult oldOverall;
  final AggregateResult newOverall;
  final AggregateResult oldDegree;
  final AggregateResult newDegree;

  const SimulateResult({
    required this.oldOverall,
    required this.newOverall,
    required this.oldDegree,
    required this.newDegree,
  });

  @override
  String toString() =>
      'SimulateResult(oldOverallGpa: ${oldOverall.gpa}, '
      'newOverallGpa: ${newOverall.gpa}, oldDegreeGpa: ${oldDegree.gpa}, '
      'newDegreeGpa: ${newDegree.gpa})';
}
