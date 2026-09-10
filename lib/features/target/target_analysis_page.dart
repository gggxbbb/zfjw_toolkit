import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zfjw_toolkit/core/stats/target_analysis.dart';
import 'package:zfjw_toolkit/core/model/course_record.dart';
import 'package:zfjw_toolkit/data/teaching_plan_repository.dart';
import 'package:zfjw_toolkit/features/gpa/state/gpa_providers.dart';
import 'package:zfjw_toolkit/features/settings/state/target_gpa.dart';
import 'package:zfjw_toolkit/features/target/plan_capture_page.dart';
import 'package:zfjw_toolkit/ui/kit/kit.dart';

final teachingPlanProvider = FutureProvider((ref) => TeachingPlanRepository().load());

class TargetAnalysisPage extends ConsumerWidget {
  const TargetAnalysisPage({super.key, required this.titleController});
  final GlassLargeTitleController titleController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(teachingPlanProvider);
    final stats = ref.watch(statsProvider);
    return CustomScrollView(
      controller: titleController.scrollController,
      slivers: [
        AppGlassLargeTitle(text: '目标分析', controller: titleController),
        SliverPadding(
          padding: AppPagePadding.body(context),
          sliver: SliverToBoxAdapter(child: plan.when(
            loading: () => const Center(child: AppGlassProgress()),
            error: (e, _) => Text('教学计划加载失败：$e'),
            data: (p) => stats.when(
              loading: () => const AppGlassProgress(),
              error: (e, _) => Text('成绩加载失败：$e'),
              data: (s) {
                if (p == null) return const _EmptyPlan();
                if (s == null) return const Text('请先在“成绩”页采集成绩，再进行目标分析。');
                final target = ref.watch(targetGpaProvider).value ?? 3.0;
                final r = analyzeTarget(current: s.overall, plan: p, targetGpa: target);
                String f(double v) => v.toStringAsFixed(2);
                final scenarios = <int, double>{
                  for (final score in [80, 85, 90])
                    score: s.preset.gradePoint(CourseRecord.fromRaw(bfzcj: '$score')) ?? 0,
                };
                double projected(double point) => p.graduationCredits == 0
                    ? (s.overall.gpa ?? 0)
                    : ((s.overall.gpa ?? 0) * r.completedCredits + point * r.remainingCredits) / p.graduationCredits;
                return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  AppGlassCard(child: Column(children: [Text('目标 GPA ${f(target)}', style: AppText.title), const SizedBox(height: 8), Text('已修 ${f(r.completedCredits)} 学分 · 剩余 ${f(r.remainingCredits)} 学分') ])),
                  const SizedBox(height: 16),
                  AppGlassGroupedCard(title: '目标达成分析', child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(r.requiredRemainingGpa == null ? '计划学分已完成' : '剩余课程平均至少需 ${f(r.requiredRemainingGpa!)} 绩点'),
                    const SizedBox(height: 8),
                    for (final e in scenarios.entries) Text('剩余课程平均 ${e.key} 分时，最终 GPA 预计 ${f(projected(e.value))}'),
                  ])),
                  const SizedBox(height: 12),
                  Text('${p.programName} · 计划毕业 ${f(p.graduationCredits)} 学分', textAlign: TextAlign.center),
                ]);
              },
            ),
          )),
        ),
      ],
    );
  }
}

class _EmptyPlan extends StatelessWidget {
  const _EmptyPlan();
  @override
  Widget build(BuildContext context) => AppGlassGroupedCard(
        title: '尚未采集教学计划',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('登录后打开“教学执行计划查看”，选择自己的计划并进入“课程信息”页，应用会自动读取全部课程。'),
            const SizedBox(height: 12),
            AppGlassButton(label: '采集教学计划', onTap: () => Navigator.of(context).push(CupertinoPageRoute(builder: (_) => const PlanCapturePage()))),
          ],
        ),
      );
}
