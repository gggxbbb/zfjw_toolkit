import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zfjw_toolkit/core/model/course_record.dart';
import 'package:zfjw_toolkit/core/model/teaching_plan.dart';
import 'package:zfjw_toolkit/core/stats/result_types.dart';
import 'package:zfjw_toolkit/core/stats/target_analysis.dart';
import 'package:zfjw_toolkit/features/gpa/state/gpa_providers.dart';
import 'package:zfjw_toolkit/features/gpa/ui/capture_entry_button.dart';
import 'package:zfjw_toolkit/features/manage/data_management_page.dart';
import 'package:zfjw_toolkit/features/settings/state/gpa_goals.dart';
import 'package:zfjw_toolkit/features/target/plan_capture_page.dart';
import 'package:zfjw_toolkit/features/target/state/plan_providers.dart';
import 'package:zfjw_toolkit/features/target/ui/what_if_section.dart';
import 'package:zfjw_toolkit/ui/kit/kit.dart';

/// 目标分析页：按「全部课程 / 学位课」范围做目标达成分析，
/// 并支持多课程 What-If 模拟（修改已修课 / 预估计划内未修课）。
class TargetAnalysisPage extends ConsumerStatefulWidget {
  const TargetAnalysisPage({super.key, required this.titleController});
  final GlassLargeTitleController titleController;

  @override
  ConsumerState<TargetAnalysisPage> createState() =>
      _TargetAnalysisPageState();
}

class _TargetAnalysisPageState extends ConsumerState<TargetAnalysisPage> {
  TargetScope _scope = TargetScope.all;

  @override
  Widget build(BuildContext context) {
    final plan = ref.watch(effectiveTeachingPlanProvider);
    final stats = ref.watch(statsProvider);
    return CustomScrollView(
      controller: widget.titleController.scrollController,
      slivers: [
        AppGlassLargeTitle(text: '目标分析', controller: widget.titleController),
        SliverPadding(
          padding: AppPagePadding.body(context),
          sliver: SliverToBoxAdapter(
            child: stats.when(
              loading: () => const Center(child: AppGlassProgress()),
              error: (e, _) => Text('成绩加载失败：$e'),
              data: (s) {
                if (s == null) return const _EmptyStats();
                final goals =
                    ref.watch(gpaGoalsProvider).value ?? const GpaGoals();
                final target = goals.targetFor(_scope);
                final minGpa = goals.minFor(_scope);
                final p = plan.value;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppGlassSegmentedControl(
                      segments: const ['全部课程', '学位课'],
                      selectedIndex: _scope.index,
                      onSegmentSelected: (i) =>
                          setState(() => _scope = TargetScope.values[i]),
                    ),
                    const SizedBox(height: AppTokens.space4),
                    if (p == null)
                      const _EmptyPlan()
                    else ...[
                      _TargetCard(
                          stats: s,
                          plan: p,
                          scope: _scope,
                          target: target,
                          minGpa: minGpa),
                      const SizedBox(height: AppTokens.space4),
                    ],
                    WhatIfSection(
                      stats: s,
                      plan: p,
                      scope: _scope,
                      targetGpa: target,
                      minGpa: minGpa,
                    ),
                    if (p != null) ...[
                      const SizedBox(height: AppTokens.space4),
                      Text(
                        '${p.programName} · 计划毕业 ${p.graduationCredits.toStringAsFixed(1)} 学分',
                        style: AppText.caption.copyWith(
                          color: AppTokens.of(context).labelTertiary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: AppTokens.space4),
                    // 数据更新入口：重新采集成绩 / 教学计划（与成绩页同源）。
                    Row(
                      children: [
                        const Expanded(
                          child: CaptureEntryButton(
                            expand: true,
                            label: '采集成绩',
                          ),
                        ),
                        const SizedBox(width: AppTokens.space3),
                        Expanded(
                          child: AppGlassButton(
                            label: p == null ? '采集教学计划' : '更新教学计划',
                            icon: CupertinoIcons.square_list,
                            style: AppButtonStyle.regular,
                            expand: true,
                            onTap: () => Navigator.of(context).push(
                              CupertinoPageRoute<void>(
                                builder: (_) => const PlanCapturePage(),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTokens.space3),
                    // 数据管理入口：编辑/新增/删除成绩与教学计划（override 保存）。
                    AppGlassButton(
                      label: '管理与编辑数据',
                      icon: CupertinoIcons.square_pencil,
                      style: AppButtonStyle.regular,
                      expand: true,
                      onTap: () => Navigator.of(context).push(
                        CupertinoPageRoute<void>(
                          builder: (_) => const DataManagementPage(),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// 目标达成分析卡：当前 GPA / 学分进度 / 达标所需剩余绩点 / 分数情景投影。
class _TargetCard extends StatelessWidget {
  const _TargetCard({
    required this.stats,
    required this.plan,
    required this.scope,
    required this.target,
    required this.minGpa,
  });

  final StatsResult stats;
  final TeachingPlan plan;
  final TargetScope scope;
  final double target;
  final double minGpa;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final scopeAll = scope == TargetScope.all;
    final scopeLabel = scopeAll ? '总' : '学位课';
    final r = analyzeTarget(
      stats: stats,
      plan: plan,
      targetGpa: target,
      scope: scope,
    );
    final rMin = analyzeTarget(
      stats: stats,
      plan: plan,
      targetGpa: minGpa,
      scope: scope,
    );
    String f(double v) => v.toStringAsFixed(2);

    // 情景投影：剩余课程平均分 → 预计最终 GPA。
    final scenarios = <int, double>{
      for (final score in [80, 85, 90])
        score:
            stats.preset.gradePoint(CourseRecord.fromRaw(bfzcj: '$score')) ?? 0,
    };
    // 规则包下百分制满分对应的绩点，用于判断目标是否可达。
    final maxPoint =
        stats.preset.gradePoint(CourseRecord.fromRaw(bfzcj: '100')) ?? 5;
    final required = r.requiredRemainingGpa;
    final requiredMin = rMin.requiredRemainingGpa;
    final current = r.currentGpa;
    final diff = current == null ? null : current - target;
    final belowMin = current != null && current < minGpa;

    return AppGlassGroupedCard(
      title: '目标达成分析（$scopeLabel）',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('$scopeLabel GPA ${current == null ? '—' : f(current)}',
                  style: AppText.title),
              const Spacer(),
              Text('目标 ${f(target)} · 最低 ${f(minGpa)}',
                  style:
                      AppText.subhead.copyWith(color: tokens.labelSecondary)),
            ],
          ),
          if (diff != null) ...[
            const SizedBox(height: AppTokens.space1),
            Text(
              diff >= 0
                  ? '已超出目标 ${f(diff)}'
                  : '距目标还差 ${f(-diff)}',
              style: AppText.footnote.copyWith(
                color: diff >= 0 ? tokens.success : tokens.danger,
              ),
            ),
          ],
          if (belowMin) ...[
            const SizedBox(height: AppTokens.space1),
            Text(
              '当前低于最低 GPA ${f(minGpa)}（硬性要求）',
              style: AppText.footnote.copyWith(color: tokens.danger),
            ),
          ],
          const SizedBox(height: AppTokens.space3),
          Text(
            '已修 ${f(r.completedCredits)} 学分 · 剩余 ${f(r.remainingCredits)} 学分'
            '${scopeAll ? '' : '（${r.remainingCourseCount} 门）'}',
            style: AppText.subhead.copyWith(color: tokens.labelSecondary),
          ),
          const SizedBox(height: AppTokens.space3),
          const AppDivider(),
          const SizedBox(height: AppTokens.space3),
          if (!scopeAll && !r.planScopeIdentified)
            Text(
              '教学计划中未识别到学位课（计划未包含学位课标记，且暂无已修学位课），'
              '无法推算学位课剩余学分。',
              style: AppText.subhead.copyWith(color: tokens.labelSecondary),
            )
          else if (required == null)
            Text(r.remainingCredits == 0 && r.completedCredits > 0
                ? '$scopeLabel计划学分已完成'
                : '暂无足够数据推算')
          else ...[
            if (required > maxPoint)
              Text(
                '即使剩余课程全部满分（绩点 ${f(maxPoint)}），'
                '$scopeLabel GPA 也无法达到目标 ${f(target)}',
                style: AppText.subhead.copyWith(color: tokens.danger),
              )
            else
              Text('达到目标需剩余课程平均至少 ${f(required)} 绩点'),
            if (requiredMin != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: requiredMin > maxPoint
                    ? Text(
                        '即使剩余课程全部满分（绩点 ${f(maxPoint)}），'
                        '$scopeLabel GPA 也无法达到最低要求 ${f(minGpa)}',
                        style:
                            AppText.subhead.copyWith(color: tokens.danger),
                      )
                    : Text(
                        requiredMin <= 0
                            ? '剩余课程及格即可满足最低 GPA ${f(minGpa)}'
                            : '保底需剩余课程平均至少 ${f(requiredMin)} 绩点（最低 GPA ${f(minGpa)}）',
                        style: AppText.footnote
                            .copyWith(color: tokens.labelSecondary),
                      ),
              ),
          ],
          if (r.remainingCredits > 0 && r.basisCredits > 0) ...[
            const SizedBox(height: AppTokens.space2),
            for (final e in scenarios.entries)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '剩余${scopeAll ? '' : '学位'}课程平均 ${e.key} 分时，最终$scopeLabel GPA 预计 ${f(r.project(e.value))}',
                  style:
                      AppText.footnote.copyWith(color: tokens.labelSecondary),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// 无成绩快照时的引导。
class _EmptyStats extends StatelessWidget {
  const _EmptyStats();

  @override
  Widget build(BuildContext context) => AppGlassGroupedCard(
        title: '暂无成绩数据',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '采集成绩后即可进行目标分析。',
              style: AppText.subhead
                  .copyWith(color: AppTokens.of(context).labelSecondary),
            ),
            const SizedBox(height: AppTokens.space3),
            const CaptureEntryButton(label: '采集成绩', expand: true),
          ],
        ),
      );
}

class _EmptyPlan extends StatelessWidget {
  const _EmptyPlan();

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppGlassGroupedCard(
            title: '尚未采集教学计划',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('登录后打开“教学执行计划查看”，选择自己的计划并进入“课程信息”页，应用会自动读取全部课程。采集后可进行目标达成分析、预估未修课程。'),
                const SizedBox(height: 12),
                AppGlassButton(
                    label: '采集教学计划',
                    onTap: () => Navigator.of(context).push(CupertinoPageRoute(
                        builder: (_) => const PlanCapturePage()))),
              ],
            ),
          ),
          const SizedBox(height: AppTokens.space4),
        ],
      );
}
