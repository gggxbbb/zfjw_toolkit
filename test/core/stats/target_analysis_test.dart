import 'package:flutter_test/flutter_test.dart';
import 'package:zfjw_toolkit/core/model/teaching_plan.dart';
import 'package:zfjw_toolkit/core/stats/result_types.dart';
import 'package:zfjw_toolkit/core/stats/target_analysis.dart';

void main() {
  test('按教学计划总学分反推目标 GPA 所需的剩余绩点', () {
    const current = AggregateResult(count: 10, gpa: 3, earnedCredits: 60, totalCredits: 60, failCount: 0, nonNumeric: 0, distribution: []);
    const plan = TeachingPlan(programName: '示例专业', graduationCredits: 120, courses: []);
    final result = analyzeTarget(current: current, plan: plan, targetGpa: 3.2);
    expect(result.remainingCredits, 60);
    expect(result.requiredRemainingGpa, closeTo(3.4, .001));
    expect(result.projectedGpas[3.5], closeTo(3.25, .001));
  });
}
