import '../model/course_record.dart';
import '../model/teaching_plan.dart';
import '../rules/rule_preset.dart';
import 'aggregate.dart';
import 'result_types.dart';

/// 学期排序键：对齐油猴 `semesterKey`：`xnmmc + ' 第' + xqmmc + '学期'`。
String semesterKeyOf(CourseRecord row) =>
    '${row.xnmmc ?? '?'} 第${row.xqmmc ?? '?'}学期';

/// 学期排序值：对齐油猴 `semesterSortVal`：`xnm*100 + xqm`。
int semesterSortValOf(CourseRecord row) =>
    ((row.xnm != null ? double.tryParse(row.xnm!) : null) ?? 0).toInt() * 100 +
    ((row.xqm != null ? double.tryParse(row.xqm!) : null) ?? 0).toInt();

/// 完整统计：规则包去重 → 免修剥离 → 总体/学位聚合 → 学期分组 →
/// 挂科/疑似误输入警告。
///
/// 对应油猴 `computeStats`：免修不参与成绩统计，单独汇总；学期按
/// [semesterSortValOf] 升序；挂科为去重后仍不及格的记录；疑似误输入为
/// 百分制 < 10 分。结果携带有效记录集与规则包，供 [simulate] 使用。
StatsResult computeStats(List<CourseRecord> raw, RulePreset preset) {
  // 1. 规则包去重得到有效记录集（保持首次出现顺序）。
  final deduped = preset.dedupe(raw);

  // 2. 免修剥离：剥离后的记录参与统计，免修单独汇总。
  final rows = <CourseRecord>[];
  final exemptList = <ExemptItem>[];
  double exemptCredits = 0;
  for (final r in deduped) {
    if (preset.isExempt(r)) {
      final c = r.credit;
      exemptList.add(ExemptItem(
        name: r.kcmc,
        credit: c,
        semester: semesterKeyOf(r),
      ));
      exemptCredits += c ?? 0;
    } else {
      rows.add(r);
    }
  }

  // 3. 总体聚合 + 学位课子集聚合。
  final degreeRows = rows.where(preset.isDegreeCourse).toList();
  final overall = aggregate(rows, preset);
  final degree = aggregate(degreeRows, preset);

  // 4. 学期分组（键 = xnmmc+' 第'+xqmmc+'学期'，排序 = xnm*100+xqm）。
  final semesters = semesterStatsOf(rows, preset);

  // 5. 挂科列表：去重取最高分后仍不及格。
  final failing = <FailingItem>[];
  for (final r in rows) {
    if (!preset.isPass(r)) {
      failing.add(FailingItem(
        name: r.kcmc,
        credit: r.credit,
        score: r.numericScore,
        semester: semesterKeyOf(r),
      ));
    }
  }

  // 6. 疑似误输入：百分制 < 10 分。
  final suspicious = <SuspiciousItem>[];
  for (final r in rows) {
    final sc = r.numericScore;
    if (sc != null && sc < 10) {
      suspicious.add(SuspiciousItem(
        name: r.kcmc,
        score: sc,
        semester: semesterKeyOf(r),
      ));
    }
  }

  return StatsResult(
    attempts: raw.length,
    overall: overall,
    degree: degree,
    semesters: semesters,
    failing: failing,
    suspicious: suspicious,
    exempt: ExemptSummary(
      count: exemptList.length,
      credits: exemptCredits,
      list: exemptList,
    ),
    rows: rows,
    preset: preset,
  );
}

/// 学期分组统计：键 = xnmmc+' 第'+xqmmc+'学期'，按 xnm*100+xqm 升序。
///
/// 从 [computeStats] 提取为公共函数，供界面按子集（如仅学位课）重算学期表现。
List<SemesterStat> semesterStatsOf(List<CourseRecord> rows, RulePreset preset) {
  final semMap = <String, _SemGroup>{};
  for (final r in rows) {
    final key = semesterKeyOf(r);
    final group = semMap.putIfAbsent(
      key,
      () => _SemGroup(key: key, sort: semesterSortValOf(r)),
    );
    group.rows.add(r);
  }
  return semMap.values.map((g) {
    final ag = aggregate(g.rows, preset);
    return SemesterStat(
      key: g.key,
      sort: g.sort,
      gpa: ag.gpa,
      credits: ag.totalCredits,
      count: ag.count,
    );
  }).toList()
    ..sort((a, b) => a.sort.compareTo(b.sort));
}

/// What-If：把多门课程替换为假设分数后重算，返回新旧总体与学位聚合对比。
///
/// [scores] 键为课程键（代码优先，缺失回退课程名）。命中有效记录集的课 →
/// 替换分数（jd 置空 → 触发规则包公式重估，对齐油猴 `simulate`）；未命中的课
/// 视为计划内未修课程，经 [planned] 提供学分/名称/学位标记后追加为新记录，
/// 未在 [planned] 中找到的键被忽略。
SimulateResult simulateAll(
  StatsResult stats,
  Map<String, double> scores, {
  List<PlannedCourse> planned = const [],
}) {
  final preset = stats.preset;

  // 复制有效记录集，命中课程者替换为假设分数。
  final pending = Map.of(scores);
  final sim = stats.rows.map<CourseRecord>((r) {
    final score = pending.remove(r.courseKey);
    if (score == null) return r;
    return CourseRecord(
      kch: r.kch,
      kcmc: r.kcmc,
      xf: r.xf,
      jd: null,
      bfzcj: score.toString(),
      cj: score.toString(),
      cjbz: r.cjbz,
      sfxwkc: r.sfxwkc,
      xnm: r.xnm,
      xqm: r.xqm,
      xnmmc: r.xnmmc,
      xqmmc: r.xqmmc,
    );
  }).toList();

  // 计划内未修课程：追加为新记录参与重估。
  for (final entry in pending.entries) {
    PlannedCourse? match;
    for (final c in planned) {
      if (plannedCourseKey(c) == entry.key) {
        match = c;
        break;
      }
    }
    final c = match;
    if (c == null) continue;
    sim.add(CourseRecord(
      kch: c.code,
      kcmc: c.name,
      xf: c.credits.toString(),
      bfzcj: entry.value.toString(),
      cj: entry.value.toString(),
      sfxwkc: c.sfxwkc,
    ));
  }

  final simDegree = sim.where(preset.isDegreeCourse).toList();

  return SimulateResult(
    oldOverall: stats.overall,
    newOverall: aggregate(sim, preset),
    oldDegree: stats.degree,
    newDegree: aggregate(simDegree, preset),
  );
}

class _SemGroup {
  final String key;
  final int sort;
  final List<CourseRecord> rows = [];
  _SemGroup({required this.key, required this.sort});
}
