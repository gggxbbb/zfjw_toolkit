import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zfjw_toolkit/core/stats/result_types.dart';
import 'package:zfjw_toolkit/features/gpa/state/gpa_providers.dart';
import 'package:zfjw_toolkit/features/gpa/ui/capture_entry_button.dart';
import 'package:zfjw_toolkit/features/gpa/ui/charts_sections.dart';
import 'package:zfjw_toolkit/features/gpa/ui/stats_sections.dart';
import 'package:zfjw_toolkit/features/manage/data_management_page.dart';
import 'package:zfjw_toolkit/features/settings/state/gpa_goals.dart';
import 'package:zfjw_toolkit/ui/kit/kit.dart';

/// 打开「数据管理」页（编辑/新增/删除成绩与教学计划，override 持久化）。
void openDataManagement(BuildContext context, {int initialIndex = 0}) {
  Navigator.of(context).push(
    CupertinoPageRoute<void>(
      builder: (_) => DataManagementPage(initialIndex: initialIndex),
    ),
  );
}

/// 成绩功能域首页：空态引导 / 完整统计页。
///
/// 数据流：latestSnapshotProvider → statsProvider（规则包 + computeStats）
/// → 各分区组件。分区信息架构对齐油猴面板（renderPanel），视觉为 iOS 26
/// 玻璃分组卡片。
///
/// 布局：iOS 26 / App Store 式——标题内嵌于滚动内容（[AppGlassLargeTitle]），
/// 内容从顶/底玻璃栏下方穿过。页面自行提供上下留白（[AppPagePadding]）。
class GpaHomePage extends ConsumerWidget {
  const GpaHomePage({super.key, required this.titleController});

  /// 由主壳传入的大标题折叠控制器（驱动顶部栏小标题联动）。
  final GlassLargeTitleController titleController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(statsProvider);
    return statsAsync.when(
      loading: () => const Center(child: AppGlassProgress()),
      error: (e, _) => Center(
        child: Text(
          '加载失败：$e',
          style: AppText.subhead.copyWith(
            color: AppTokens.of(context).labelSecondary,
          ),
          textAlign: TextAlign.center,
        ),
      ),
      data: (stats) => stats == null
          ? _EmptyState(titleController: titleController)
          : _StatsPage(stats: stats, titleController: titleController),
    );
  }
}

/// 页面骨架：内嵌大标题 + 内容 slivers。
///
/// 两种状态（空态/有数据）共用同一套滚动结构与留白。
class _PageScroll extends StatelessWidget {
  const _PageScroll({
    required this.titleController,
    required this.slivers,
    this.centerContent = false,
  });

  final GlassLargeTitleController titleController;
  final List<Widget> slivers;

  /// 空态时把内容垂直居中（撑满一屏）。
  final bool centerContent;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      controller: titleController.scrollController,
      slivers: [
        // 页面内嵌标题（App Store 式），自带状态栏 + 导航栏留白。
        AppGlassLargeTitle(text: '成绩', controller: titleController),
        if (centerContent)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: AppPagePadding.body(context),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: slivers,
              ),
            ),
          )
        else
          SliverPadding(
            padding: AppPagePadding.body(context),
            sliver: SliverList.list(children: slivers),
          ),
      ],
    );
  }
}

/// 空态：无任何成绩快照时的引导。
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.titleController});

  final GlassLargeTitleController titleController;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return _PageScroll(
      titleController: titleController,
      centerContent: true,
      slivers: [
        Icon(
          CupertinoIcons.book_solid,
          size: 56,
          color: tokens.labelTertiary,
        ),
        const SizedBox(height: AppTokens.space4),
        Text(
          '暂无成绩数据',
          style: AppText.title.copyWith(
            fontSize: 20,
            color: tokens.labelPrimary,
          ),
        ),
        const SizedBox(height: AppTokens.space2),
        Text(
          '从教务系统采集成绩后，这里会展示完整的统计分析。',
          textAlign: TextAlign.center,
          style: AppText.subhead.copyWith(color: tokens.labelSecondary),
        ),
        const SizedBox(height: AppTokens.space5),
        const CaptureEntryButton(),
        const SizedBox(height: AppTokens.space3),
        AppGlassButton(
          label: '手动添加成绩',
          icon: CupertinoIcons.square_pencil,
          style: AppButtonStyle.regular,
          onTap: () => openDataManagement(context),
        ),
      ],
    );
  }
}

/// 有数据时的完整统计页（滚动布局，分区 = 油猴 renderPanel 的 app 化）。
class _StatsPage extends ConsumerWidget {
  const _StatsPage({required this.stats, required this.titleController});

  final StatsResult stats;
  final GlassLargeTitleController titleController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = AppTokens.of(context);
    final goals = ref.watch(gpaGoalsProvider).value;
    return _PageScroll(
      titleController: titleController,
      slivers: [
        OverviewCard(
          stats: stats,
          targetGpaAll: goals?.targetAll,
          targetGpaDegree: goals?.targetDegree,
        ),
        const SizedBox(height: AppTokens.space4),
        WarningsSection(stats: stats),
        if (stats.failing.isNotEmpty || stats.suspicious.isNotEmpty)
          const SizedBox(height: AppTokens.space4),
        SemestersSection(
          stats: stats,
          targetGpaAll: goals?.targetAll,
          targetGpaDegree: goals?.targetDegree,
        ),
        if (stats.semesters.isNotEmpty) const SizedBox(height: AppTokens.space4),
        DistributionSection(stats: stats),
        const SizedBox(height: AppTokens.space5),
        Text(
          '共 ${stats.attempts} 条成绩记录，同课程多次修读已按最高分去重；'
          '绩点取教务官方值'
          '${stats.exempt.count > 0 ? '；免修 ${stats.exempt.count} 门不参与统计' : ''}。',
          style: AppText.caption.copyWith(color: tokens.labelTertiary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppTokens.space4),
        // 有数据后的成绩更新入口（与空态大按钮同源）。
        const CaptureEntryButton(expand: true),
        const SizedBox(height: AppTokens.space3),
        // 数据管理入口：编辑/新增/删除成绩与教学计划（override 保存）。
        AppGlassButton(
          label: '管理与编辑数据',
          icon: CupertinoIcons.square_pencil,
          style: AppButtonStyle.regular,
          expand: true,
          onTap: () => openDataManagement(context),
        ),
      ],
    );
  }
}
