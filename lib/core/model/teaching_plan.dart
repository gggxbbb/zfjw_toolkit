import 'course_record.dart';

/// 教务系统「教学执行计划」中的一门计划课程。
class PlannedCourse {
  const PlannedCourse({
    required this.code,
    required this.name,
    required this.credits,
    required this.suggestedYear,
    required this.suggestedTerm,
  });

  final String code;
  final String name;
  final double credits;
  final String suggestedYear;
  final String suggestedTerm;

  factory PlannedCourse.fromJson(Map<String, dynamic> row) => PlannedCourse(
        code: cleanField(row['kch'] ?? row['kch_id'] ?? row['kcdm']),
        name: cleanField(row['kcmc'] ?? row['kcmc_id']),
        credits: parseNum(row['xf'] ?? row['xf_id']) ?? 0,
        suggestedYear: cleanField(row['jynj'] ?? row['jxzxjhnj']),
        suggestedTerm: cleanField(row['jyxq'] ?? row['jxzxjhxq']),
      );

  Map<String, dynamic> toJson() => {
        'code': code,
        'name': name,
        'credits': credits,
        'suggestedYear': suggestedYear,
        'suggestedTerm': suggestedTerm,
      };

  factory PlannedCourse.fromStoredJson(Map<String, dynamic> json) => PlannedCourse(
        code: json['code'] as String? ?? '',
        name: json['name'] as String? ?? '',
        credits: (json['credits'] as num?)?.toDouble() ?? 0,
        suggestedYear: json['suggestedYear'] as String? ?? '',
        suggestedTerm: json['suggestedTerm'] as String? ?? '',
      );
}

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
