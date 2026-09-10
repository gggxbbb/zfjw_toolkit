import '../model/teaching_plan.dart';
import 'result_types.dart';

class TargetAnalysis {
  const TargetAnalysis({
    required this.completedCredits,
    required this.remainingCredits,
    required this.requiredRemainingGpa,
    required this.projectedGpas,
  });
  final double completedCredits;
  final double remainingCredits;
  final double? requiredRemainingGpa;
  final Map<double, double> projectedGpas;
}

TargetAnalysis analyzeTarget({
  required AggregateResult current,
  required TeachingPlan plan,
  required double targetGpa,
}) {
  final completed = current.totalCredits;
  final remaining =
      (plan.graduationCredits - completed).clamp(0, double.infinity).toDouble();
  final currentGpa = current.gpa ?? 0;
  double project(double remainingGpa) => plan.graduationCredits == 0
      ? currentGpa
      : (currentGpa * completed + remainingGpa * remaining) / plan.graduationCredits;
  return TargetAnalysis(
    completedCredits: completed,
    remainingCredits: remaining,
    requiredRemainingGpa: remaining == 0
        ? null
        : (targetGpa * plan.graduationCredits - currentGpa * completed) / remaining,
    projectedGpas: {3.0: project(3.0), 3.5: project(3.5), 4.0: project(4.0)},
  );
}
