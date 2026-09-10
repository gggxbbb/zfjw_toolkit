import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zfjw_toolkit/core/stats/result_types.dart';
import 'package:zfjw_toolkit/features/gpa/state/gpa_providers.dart';
import 'package:zfjw_toolkit/features/gpa/ui/capture_entry_button.dart';
import 'package:zfjw_toolkit/features/gpa/ui/import_entry_button.dart';
import 'package:zfjw_toolkit/features/gpa/ui/stats_sections.dart';
import 'package:zfjw_toolkit/features/gpa/ui/charts_sections.dart';
import 'package:zfjw_toolkit/features/gpa/ui/what_if_card.dart';
import 'package:zfjw_toolkit/features/settings/state/target_gpa.dart';

/// 成绩功能域首页：空态引导 / 完整统计页。
///
/// 数据流：latestSnapshotProvider → statsProvider（规则包 + computeStats）
/// → 各分区组件。分区信息架构对齐油猴面板（renderPanel）。
class GpaHomePage extends ConsumerWidget {
  const GpaHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(statsProvider);
    return statsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('加载失败：$e')),
      data: (stats) =>
          stats == null ? const _EmptyState() : _StatsPage(stats: stats),
    );
  }
}

/// 空态：无任何成绩快照时的引导。
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.grade_outlined, size: 56),
              SizedBox(height: 16),
              Text(
                '暂无成绩数据',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                '从教务系统采集成绩，或导入已保存的成绩页面。',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13),
              ),
              SizedBox(height: 20),
              Wrap(
                spacing: 12,
                children: [CaptureEntryButton(), ImportEntryButton()],
              ),
            ],
          ),
        ),
      );
}

/// 有数据时的完整统计页（滚动布局，分区 = 油猴 renderPanel 的 app 化）。
class _StatsPage extends ConsumerWidget {
  const _StatsPage({required this.stats});

  final StatsResult stats;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final target = ref.watch(targetGpaProvider).value;
    return ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          OverviewCard(stats: stats, targetGpa: target),
          const SizedBox(height: 12),
          WarningsSection(stats: stats),
          const SizedBox(height: 12),
          SemestersSection(semesters: stats.semesters, targetGpa: target),
          const SizedBox(height: 12),
          WhatIfCard(stats: stats),
          const SizedBox(height: 12),
          DistributionSection(overall: stats.overall),
          const SizedBox(height: 16),
          Text(
            '共 ${stats.attempts} 条成绩记录，同课程多次修读已按最高分去重；'
            '绩点取教务官方值'
            '${stats.exempt.count > 0 ? '；免修 ${stats.exempt.count} 门不参与统计' : ''}。',
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurface.withAlpha(140),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton.icon(
              onPressed: () => ref.invalidate(latestSnapshotProvider),
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('重新加载', style: TextStyle(fontSize: 12)),
            ),
          ),
        ],
      );
  }
}
