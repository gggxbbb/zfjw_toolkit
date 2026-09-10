import '../model/course_record.dart';
import '../rules/rule_preset.dart';
import 'result_types.dart';

/// 分数落入的分布档位索引（对齐油猴 BUCKETS）：
/// 0:[90,100] 1:[80,90) 2:[70,80) 3:[60,70) 4:<60。
int? _bucketIndex(double s) {
  if (s >= 90) return 0;
  if (s >= 80) return 1;
  if (s >= 70) return 2;
  if (s >= 60) return 3;
  return 4;
}

/// 单组统计：对一组课程记录聚合出 GPA / 加权·算术平均分 / 已获·已修学分 /
/// 门数 / 不及格数 / 非百分制数 / 最高最低分 / 五档分布。
///
/// 对应油猴 `aggregate` 函数：
/// - GPA = Σ(xf·jd) / Σxf，仅统计有有效绩点且学分的课；
/// - 已获学分按 [RulePreset.isPass] 判定累加；
/// - `gpa` 为 `null` 表示无有效绩点数据。
AggregateResult aggregate(List<CourseRecord> rows, RulePreset preset) {
  double gpaW = 0, gpaC = 0; // Σ(xf·jd), Σxf（有有效绩点与学分的课）
  double wW = 0, wC = 0, sum = 0; // 加权/算术平均累加
  int nScored = 0;
  double earned = 0, total = 0; // 已获/已修学分
  int fail = 0, nonNumeric = 0;
  double? maxScore;
  String? maxCourse;
  double? minScore;
  String? minCourse;
  final dist = List<int>.filled(distributionLabels.length, 0);

  for (final row in rows) {
    final xf = row.credit;
    final jd = preset.gradePoint(row);
    final s = row.numericScore;

    if (xf != null) {
      total += xf;
      if (preset.isPass(row)) earned += xf;
    }
    if (xf != null && jd != null) {
      gpaW += xf * jd;
      gpaC += xf;
    }

    if (s != null) {
      if (xf != null) {
        wW += xf * s;
        wC += xf;
      }
      sum += s;
      nScored++;

      if (maxScore == null || s > maxScore) {
        maxScore = s;
        maxCourse = row.kcmc;
      }
      if (minScore == null || s < minScore) {
        minScore = s;
        minCourse = row.kcmc;
      }

      final b = _bucketIndex(s);
      if (b != null) dist[b]++;
    } else {
      nonNumeric++;
    }

    if (!preset.isPass(row)) fail++;
  }

  return AggregateResult(
    count: rows.length,
    gpa: gpaC > 0 ? gpaW / gpaC : null,
    weightedAvg: wC > 0 ? wW / wC : null,
    arithAvg: nScored > 0 ? sum / nScored : null,
    earnedCredits: earned,
    totalCredits: total,
    failCount: fail,
    nonNumeric: nonNumeric,
    maxScore: maxScore,
    maxCourse: maxCourse,
    minScore: minScore,
    minCourse: minCourse,
    distribution: dist,
  );
}
