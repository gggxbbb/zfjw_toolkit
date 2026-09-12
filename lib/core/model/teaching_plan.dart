import 'course_record.dart';

/// 教务系统「教学执行计划」中的一门计划课程。
class PlannedCourse {
  const PlannedCourse({
    required this.code,
    required this.name,
    required this.credits,
    required this.suggestedYear,
    required this.suggestedTerm,
    this.sfxwkc = '',
  });

  final String code;
  final String name;
  final double credits;
  final String suggestedYear;
  final String suggestedTerm;

  /// 是否学位课。正方不同页面的字段名不同：成绩单用 `sfxwkc`，
  /// 教学执行计划课程信息 grid 用 `zyzgkcbj`（列名"是否学位课程"）。
  final String sfxwkc;

  factory PlannedCourse.fromJson(Map<String, dynamic> row) => PlannedCourse(
        code: cleanField(row['kch'] ?? row['kch_id'] ?? row['kcdm']),
        name: cleanField(row['kcmc'] ?? row['kcmc_id']),
        credits: parseNum(row['xf'] ?? row['xf_id']) ?? 0,
        suggestedYear:
            cleanField(row['jyxdxnm'] ?? row['jynj'] ?? row['jxzxjhnj']),
        suggestedTerm:
            cleanField(row['jyxdxqm'] ?? row['jyxq'] ?? row['jxzxjhxq']),
        sfxwkc: cleanField(row['sfxwkc'] ??
            row['sfxwkc_id'] ??
            row['sfxw'] ??
            row['zyzgkcbj']),
      );

  Map<String, dynamic> toJson() => {
        'code': code,
        'name': name,
        'credits': credits,
        'suggestedYear': suggestedYear,
        'suggestedTerm': suggestedTerm,
        'sfxwkc': sfxwkc,
      };

  factory PlannedCourse.fromStoredJson(Map<String, dynamic> json) => PlannedCourse(
        code: json['code'] as String? ?? '',
        name: json['name'] as String? ?? '',
        credits: (json['credits'] as num?)?.toDouble() ?? 0,
        suggestedYear: json['suggestedYear'] as String? ?? '',
        suggestedTerm: json['suggestedTerm'] as String? ?? '',
        sfxwkc: json['sfxwkc'] as String? ?? '',
      );
}

/// 计划课程键：与 [CourseRecord.courseKey] 同规则（课程代码优先，缺失回退课程名），
/// 用于计划课程与成绩记录的互相匹配。
String plannedCourseKey(PlannedCourse c) => c.code.isNotEmpty ? c.code : c.name;

/// 一次完整教学计划采集；与成绩快照独立保存。
class TeachingPlan {
  const TeachingPlan({
    required this.programName,
    required this.graduationCredits,
    required this.courses,
  });

  final String programName;
  final double graduationCredits;
  final List<PlannedCourse> courses;

  Map<String, dynamic> toJson() => {
        'programName': programName,
        'graduationCredits': graduationCredits,
        'courses': courses.map((e) => e.toJson()).toList(),
      };

  factory TeachingPlan.fromJson(Map<String, dynamic> json) => TeachingPlan(
        programName: json['programName'] as String? ?? '',
        graduationCredits: (json['graduationCredits'] as num?)?.toDouble() ?? 0,
        courses: (json['courses'] as List<dynamic>? ?? [])
            .map((e) => PlannedCourse.fromStoredJson(e as Map<String, dynamic>))
            .toList(),
      );
}
