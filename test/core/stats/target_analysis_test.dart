import 'package:flutter_test/flutter_test.dart';
import 'package:zfjw_toolkit/core/model/course_record.dart';
import 'package:zfjw_toolkit/core/model/teaching_plan.dart';
import 'package:zfjw_toolkit/core/rules/presets/xzhmu.dart';
import 'package:zfjw_toolkit/core/stats/stats_engine.dart';
import 'package:zfjw_toolkit/core/stats/target_analysis.dart';

const preset = XzhmuRulePreset();

CourseRecord rec({
  String? kch,
  String? kcmc,
  String? xf,
  String? bfzcj,
  String? sfxwkc,
}) =>
    CourseRecord.fromRaw(
      kch: kch,
      kcmc: kcmc,
      xf: xf,
      bfzcj: bfzcj,
      cj: bfzcj,
      sfxwkc: sfxwkc,
    );

void main() {
  group('analyzeTarget · 全部课程', () {
    test('按教学计划总学分反推目标 GPA 所需的剩余绩点', () {
      // 已修 60 学分、GPA 3.0；计划毕业 120 学分 → 剩余 60。
      final stats = computeStats([
        rec(kch: 'A', kcmc: '甲', xf: '60', bfzcj: '80'), // jd 3.0
      ], preset);
      const plan = TeachingPlan(
          programName: '示例专业', graduationCredits: 120, courses: []);
      final r = analyzeTarget(
          stats: stats, plan: plan, targetGpa: 3.2, scope: TargetScope.all);
      expect(r.completedCredits, 60);
      expect(r.remainingCredits, 60);
      expect(r.requiredRemainingGpa, closeTo(3.4, .001));
      expect(r.project(3.5), closeTo(3.25, .001));
    });
  });

  group('analyzeTarget · 学位课', () {
    // 已修：A 学位课 80分 xf4（jd3.0），B 非学位 90分 xf2。
    // 计划：A（已通过）、C 学位课 xf3（未修，计划自带标记）、D 非学位 xf2。
    final stats = computeStats([
      rec(kch: 'A', kcmc: '核心', xf: '4', bfzcj: '80', sfxwkc: '是'),
      rec(kch: 'B', kcmc: '选修', xf: '2', bfzcj: '90', sfxwkc: '否'),
    ], preset);
    const plan = TeachingPlan(
      programName: '示例专业',
      graduationCredits: 9,
      courses: [
        PlannedCourse(
            code: 'A',
            name: '核心',
            credits: 4,
            suggestedYear: '',
            suggestedTerm: ''),
        PlannedCourse(
            code: 'C',
            name: '学位新课',
            credits: 3,
            suggestedYear: '',
            suggestedTerm: '',
            sfxwkc: '是'),
        PlannedCourse(
            code: 'D',
            name: '普通新课',
            credits: 2,
            suggestedYear: '',
            suggestedTerm: ''),
      ],
    );

    test('剩余学分 = 未通过的计划学位课学分之和', () {
      final r = analyzeTarget(
          stats: stats, plan: plan, targetGpa: 3.2, scope: TargetScope.degree);
      expect(r.planScopeIdentified, isTrue);
      expect(r.completedCredits, 4); // 仅学位课学分
      expect(r.remainingCredits, 3); // C
      expect(r.remainingCourseCount, 1);
      // 学位 GPA 基准 = 4+3=7 学分：required = (3.2·7 − 3.0·4)/3 = 10.4/3
      expect(r.requiredRemainingGpa, closeTo(10.4 / 3, .001));
    });

    test('计划课程无学位标记时按已修学位课记录匹配', () {
      // 去掉 C 的 sfxwkc 标记 → 计划里只能识别出 A（匹配已修学位记录）。
      const noFlagPlan = TeachingPlan(
        programName: '示例专业',
        graduationCredits: 9,
        courses: [
          PlannedCourse(
              code: 'A',
              name: '核心',
              credits: 4,
              suggestedYear: '',
              suggestedTerm: ''),
          PlannedCourse(
              code: 'C',
              name: '学位新课',
              credits: 3,
              suggestedYear: '',
              suggestedTerm: ''),
        ],
      );
      final r = analyzeTarget(
          stats: stats,
          plan: noFlagPlan,
          targetGpa: 3.2,
          scope: TargetScope.degree);
      expect(r.planScopeIdentified, isTrue);
      // C 未通过记录且未被识别为学位课 → 剩余 0
      expect(r.remainingCredits, 0);
      expect(r.requiredRemainingGpa, isNull);
    });

    test('计划与记录都无学位课时标记为未识别', () {
      final plainStats = computeStats([
        rec(kch: 'B', kcmc: '选修', xf: '2', bfzcj: '90', sfxwkc: '否'),
      ], preset);
      const plainPlan = TeachingPlan(
        programName: '示例专业',
        graduationCredits: 4,
        courses: [
          PlannedCourse(
              code: 'B',
              name: '选修',
              credits: 2,
              suggestedYear: '',
              suggestedTerm: ''),
        ],
      );
      final r = analyzeTarget(
          stats: plainStats,
          plan: plainPlan,
          targetGpa: 3.0,
          scope: TargetScope.degree);
      expect(r.planScopeIdentified, isFalse);
    });
  });
}
