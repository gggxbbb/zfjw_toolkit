import '../../model/course_record.dart';
import '../rule_preset.dart';

/// 等级文本通过判定集合。
const List<String> passTexts = [
  '合格',
  '通过',
  '优秀',
  '良好',
  '中等',
  '及格',
];

/// 学位课编码值兜底映射（sfxwkc 非「是」文本时的编码值）。
const Map<String, int> degreeYes = {
  '1': 1,
  'true': 1,
  'Y': 1,
  'y': 1,
  'yes': 1,
};

/// 徐医（xzhmu）规则包。
///
/// 规则对齐油猴脚本 `jwpt-gpa.user.js`（成绩语义即徐医官方规则）：
/// - 绩点优先官方 jd，缺失回退 (score-50)/10，<60 记 0；
/// - 重修/补考取历次最高分；
/// - 免修记录优先于一切考试记录；
/// - 学位课 = sfxwkc 含「是」（含编码值 1/true/Y 兜底）；
/// - 免修 = 成绩或备注含「免修」。
class XzhmuRulePreset extends RulePreset {
  const XzhmuRulePreset();

  @override
  String get id => 'xzhmu';

  @override
  double? gradePoint(CourseRecord r) {
    final jd = r.officialGradePoint;
    if (jd != null) return jd;
    final s = r.numericScore;
    if (s == null) return null;
    return s >= 60 ? (s - 50) / 10 : 0;
  }

  @override
  bool isDegreeCourse(CourseRecord r) {
    final v = r.sfxwkc ?? '';
    if (v.contains('是')) return true;
    return degreeYes[cleanField(v)] == 1;
  }

  @override
  bool isExempt(CourseRecord r) {
    return (r.cj ?? '').contains('免修') || (r.cjbz ?? '').contains('免修');
  }

  @override
  bool isPass(CourseRecord r) {
    final jd = r.officialGradePoint;
    if (jd != null) return jd > 0;
    final s = r.numericScore;
    if (s != null) return s >= 60;
    final txt = (r.cj ?? r.bfzcj ?? '').trim();
    return passTexts.contains(txt);
  }

  @override
  List<CourseRecord> dedupe(List<CourseRecord> records) {
    final best = <String, _BestEntry>{};
    final order = <String>[];
    for (final row in records) {
      final key = row.courseKey;
      final score = row.numericScore;
      final entry = best[key];
      if (entry == null) {
        best[key] = _BestEntry(row, score, isExempt(row));
        order.add(key);
        continue;
      }
      final currentExempt = entry.exempt;
      final rowExempt = isExempt(row);
      if (rowExempt && !currentExempt) {
        best[key] = _BestEntry(row, score, true);
      } else if (!rowExempt && currentExempt) {
        // 保持既有免修记录
      } else if (score != null && (entry.score == null || score > entry.score!)) {
        best[key] = _BestEntry(row, score, currentExempt);
      }
    }
    return [for (final k in order) best[k]!.row];
  }
}

class _BestEntry {
  final CourseRecord row;
  final double? score;
  final bool exempt;
  _BestEntry(this.row, this.score, this.exempt);
}
