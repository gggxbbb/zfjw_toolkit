import 'course_record.dart';
import 'teaching_plan.dart';

/// 一条成绩记录的字段补丁：以 (courseKey, xnm, xqm) 定位采集记录，
/// 非 null 字段覆盖原值；[deleted] 为 true 时整条记录视为删除。
///
/// 补丁独立于快照存储：重新采集生成新快照后，补丁按同样的键再次生效，
/// 因此用户编辑不会因重新获取而丢失。课程代码/名称/学期不作为可编辑字段
/// （它们是定位键），学期在新增记录时可指定。
class RecordPatch {
  const RecordPatch({
    required this.courseKey,
    this.xnm = '',
    this.xqm = '',
    this.deleted = false,
    this.cj,
    this.bfzcj,
    this.xf,
    this.jd,
    this.sfxwkc,
  });

  /// 定位键：课程代码（缺失时为课程名），与 [CourseRecord.courseKey] 同规则。
  final String courseKey;

  /// 定位键：学年码 / 学期码（空串对应原始记录缺失该字段）。
  final String xnm;
  final String xqm;

  /// 是否删除（隐藏）该记录。
  final bool deleted;

  /// 覆盖字段；null 表示不覆盖（跟随最近一次采集值）。
  final String? cj;
  final String? bfzcj;
  final String? xf;
  final String? jd;
  final String? sfxwkc;

  /// 是否为空补丁（不删除也不覆盖任何字段）——不应被持久化。
  bool get isEmpty =>
      !deleted &&
      cj == null &&
      bfzcj == null &&
      xf == null &&
      jd == null &&
      sfxwkc == null;

  /// 键是否一致（用于 upsert 去重）。
  bool sameKey(RecordPatch other) =>
      courseKey == other.courseKey && xnm == other.xnm && xqm == other.xqm;

  /// 是否命中某条采集记录。
  bool matches(CourseRecord r) =>
      r.courseKey == courseKey && (r.xnm ?? '') == xnm && (r.xqm ?? '') == xqm;

  /// 应用到原始记录上，返回覆盖后的新记录。
  CourseRecord applyTo(CourseRecord r) => CourseRecord(
        kch: r.kch,
        kcmc: r.kcmc,
        xf: xf ?? r.xf,
        jd: jd ?? r.jd,
        bfzcj: bfzcj ?? r.bfzcj,
        cj: cj ?? r.cj,
        cjbz: r.cjbz,
        sfxwkc: sfxwkc ?? r.sfxwkc,
        xnm: r.xnm,
        xqm: r.xqm,
        xnmmc: r.xnmmc,
        xqmmc: r.xqmmc,
      );
}

/// 成绩 overrides 全集：字段补丁 + 手动新增的记录。
class RecordOverrides {
  const RecordOverrides({
    this.patches = const [],
    this.additions = const [],
  });

  /// 对采集记录的修改/删除补丁。
  final List<RecordPatch> patches;

  /// 手动新增的成绩记录（完整记录，采集不到时也能存在）。
  final List<CourseRecord> additions;

  bool get isEmpty => patches.isEmpty && additions.isEmpty;

  /// 返回新增记录中与给定键冲突（同课程同学期）的那条；无则 null。
  CourseRecord? additionAt(String courseKey, String xnm, String xqm) {
    for (final a in additions) {
      if (a.courseKey == courseKey &&
          (a.xnm ?? '') == xnm &&
          (a.xqm ?? '') == xqm) {
        return a;
      }
    }
    return null;
  }

  /// upsert 一条补丁：同键替换，空补丁则移除同键补丁。
  RecordOverrides upsertPatch(RecordPatch patch) {
    final next = [
      for (final p in patches)
        if (!p.sameKey(patch)) p,
    ];
    if (!patch.isEmpty) next.add(patch);
    return RecordOverrides(patches: next, additions: additions);
  }

  /// 移除同键补丁（恢复原始值/撤销删除）。
  RecordOverrides removePatch(String courseKey, String xnm, String xqm) =>
      upsertPatch(RecordPatch(courseKey: courseKey, xnm: xnm, xqm: xqm));

  /// 新增/替换一条手动记录（同课程同学期视为同一条，后写覆盖）。
  RecordOverrides upsertAddition(CourseRecord record) {
    final next = [
      for (final a in additions)
        if (!(a.courseKey == record.courseKey &&
            (a.xnm ?? '') == (record.xnm ?? '') &&
            (a.xqm ?? '') == (record.xqm ?? '')))
          a,
      record,
    ];
    return RecordOverrides(patches: patches, additions: next);
  }

  /// 移除一条手动记录。
  RecordOverrides removeAddition(String courseKey, String xnm, String xqm) =>
      RecordOverrides(
        patches: patches,
        additions: [
          for (final a in additions)
            if (!(a.courseKey == courseKey &&
                (a.xnm ?? '') == xnm &&
                (a.xqm ?? '') == xqm))
              a,
        ],
      );
}

/// 应用成绩 overrides：删除 → 补丁覆盖 → 追加手动记录。
///
/// 补丁按 (courseKey, xnm, xqm) 匹配采集记录；未命中的补丁保留在存储中，
/// 待重新采集出现匹配记录时再生效。
List<CourseRecord> applyRecordOverrides(
  List<CourseRecord> raw,
  RecordOverrides overrides,
) {
  if (overrides.isEmpty) return List.of(raw);
  final out = <CourseRecord>[];
  for (final r in raw) {
    RecordPatch? patch;
    for (final p in overrides.patches) {
      if (p.matches(r)) {
        patch = p;
        break;
      }
    }
    if (patch == null) {
      out.add(r);
    } else if (!patch.deleted) {
      out.add(patch.applyTo(r));
    }
  }
  out.addAll(overrides.additions);
  return out;
}

/// 教学计划课程的字段补丁：以 [plannedCourseKey] 定位，非 null 字段覆盖原值。
class PlanCoursePatch {
  const PlanCoursePatch({
    required this.key,
    this.deleted = false,
    this.credits,
    this.sfxwkc,
    this.suggestedYear,
    this.suggestedTerm,
  });

  /// 定位键：课程代码（缺失时为课程名）。
  final String key;

  /// 是否从计划中删除（隐藏）该课程。
  final bool deleted;

  /// 覆盖字段；null 表示不覆盖。
  final double? credits;
  final String? sfxwkc;
  final String? suggestedYear;
  final String? suggestedTerm;

  bool get isEmpty =>
      !deleted &&
      credits == null &&
      sfxwkc == null &&
      suggestedYear == null &&
      suggestedTerm == null;

  PlannedCourse applyTo(PlannedCourse c) => PlannedCourse(
        code: c.code,
        name: c.name,
        credits: credits ?? c.credits,
        suggestedYear: suggestedYear ?? c.suggestedYear,
        suggestedTerm: suggestedTerm ?? c.suggestedTerm,
        sfxwkc: sfxwkc ?? c.sfxwkc,
      );
}

/// 教学计划 overrides 全集：计划信息覆盖 + 课程补丁 + 手动新增课程。
class PlanOverrides {
  const PlanOverrides({
    this.programName,
    this.graduationCredits,
    this.patches = const [],
    this.additions = const [],
  });

  /// 覆盖计划名称；null 跟随采集值。
  final String? programName;

  /// 覆盖毕业学分要求；null 跟随采集值。
  final double? graduationCredits;

  /// 对计划内课程的修改/删除补丁。
  final List<PlanCoursePatch> patches;

  /// 手动新增的计划课程。
  final List<PlannedCourse> additions;

  bool get isEmpty =>
      programName == null &&
      graduationCredits == null &&
      patches.isEmpty &&
      additions.isEmpty;

  PlannedCourse? additionAt(String key) {
    for (final a in additions) {
      if (plannedCourseKey(a) == key) return a;
    }
    return null;
  }

  PlanOverrides upsertPatch(PlanCoursePatch patch) {
    final next = [
      for (final p in patches)
        if (p.key != patch.key) p,
    ];
    if (!patch.isEmpty) next.add(patch);
    return PlanOverrides(
      programName: programName,
      graduationCredits: graduationCredits,
      patches: next,
      additions: additions,
    );
  }

  PlanOverrides removePatch(String key) =>
      upsertPatch(PlanCoursePatch(key: key));

  PlanOverrides upsertAddition(PlannedCourse course) {
    final key = plannedCourseKey(course);
    return PlanOverrides(
      programName: programName,
      graduationCredits: graduationCredits,
      patches: patches,
      additions: [
        for (final a in additions)
          if (plannedCourseKey(a) != key) a,
        course,
      ],
    );
  }

  PlanOverrides removeAddition(String key) => PlanOverrides(
        programName: programName,
        graduationCredits: graduationCredits,
        patches: patches,
        additions: [
          for (final a in additions)
            if (plannedCourseKey(a) != key) a,
        ],
      );

  PlanOverrides copyWithPlanInfo({
    String? Function()? programName,
    double? Function()? graduationCredits,
  }) =>
      PlanOverrides(
        programName: programName != null ? programName() : this.programName,
        graduationCredits: graduationCredits != null
            ? graduationCredits()
            : this.graduationCredits,
        patches: patches,
        additions: additions,
      );
}

/// 应用教学计划 overrides：删除 → 补丁覆盖 → 追加手动课程 → 覆盖计划信息。
TeachingPlan applyPlanOverrides(TeachingPlan raw, PlanOverrides overrides) {
  if (overrides.isEmpty) return raw;
  final courses = <PlannedCourse>[];
  for (final c in raw.courses) {
    PlanCoursePatch? patch;
    for (final p in overrides.patches) {
      if (p.key == plannedCourseKey(c)) {
        patch = p;
        break;
      }
    }
    if (patch == null) {
      courses.add(c);
    } else if (!patch.deleted) {
      courses.add(patch.applyTo(c));
    }
  }
  courses.addAll(overrides.additions);
  return TeachingPlan(
    programName: overrides.programName ?? raw.programName,
    graduationCredits: overrides.graduationCredits ?? raw.graduationCredits,
    courses: courses,
  );
}
