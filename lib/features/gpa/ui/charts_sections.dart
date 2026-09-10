import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/cupertino.dart';

import 'package:zfjw_toolkit/core/stats/result_types.dart';
import 'package:zfjw_toolkit/core/stats/stats_engine.dart' show semesterStatsOf;
import 'package:zfjw_toolkit/core/stats/target_analysis.dart';
import 'package:zfjw_toolkit/ui/kit/kit.dart';

import 'stats_sections.dart' show fmt;

/// 范围切换器：全部课程 / 学位课（紧凑分段控件，置于分区标题行右侧）。
class _ScopeToggle extends StatelessWidget {
  const _ScopeToggle({required this.scope, required this.onChanged});

  final TargetScope scope;
  final ValueChanged<TargetScope> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: AppGlassSegmentedControl(
        segments: const ['全部', '学位课'],
        selectedIndex: scope.index,
        onSegmentSelected: (i) => onChanged(TargetScope.values[i]),
        height: 28,
      ),
    );
  }
}

/// 学期区：每学期一行统计 + GPA 趋势折线（含目标虚线）。
/// 支持全部课程/学位课范围切换，学位课按学期重算子集统计。
class SemestersSection extends StatefulWidget {
  const SemestersSection({
    super.key,
    required this.stats,
    this.targetGpaAll,
    this.targetGpaDegree,
  });

  final StatsResult stats;

  /// 目标 GPA（全部课程/学位课，可选，趋势线叠加虚线）。
  final double? targetGpaAll;
  final double? targetGpaDegree;

  @override
  State<SemestersSection> createState() => _SemestersSectionState();
}

class _SemestersSectionState extends State<SemestersSection> {
  TargetScope _scope = TargetScope.all;

  @override
  Widget build(BuildContext context) {
    final stats = widget.stats;
    final scopeAll = _scope == TargetScope.all;
    final semesters = scopeAll
        ? stats.semesters
        : semesterStatsOf(
            stats.rows.where(stats.preset.isDegreeCourse).toList(),
            stats.preset,
          );
    final targetGpa = scopeAll ? widget.targetGpaAll : widget.targetGpaDegree;

    if (stats.semesters.isEmpty) return const SizedBox.shrink();
    final tokens = AppTokens.of(context);

    final spots = <FlSpot>[
      for (var i = 0; i < semesters.length; i++)
        if (semesters[i].gpa != null)
          FlSpot(i.toDouble(), semesters[i].gpa!),
    ];

    return AppGlassGroupedCard(
      title: '学期表现',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: AppCardTitle(
                  '各学期（${semesters.length} 个）'
                  '${scopeAll ? '' : ' · 仅学位课'}',
                ),
              ),
              _ScopeToggle(
                scope: _scope,
                onChanged: (s) => setState(() => _scope = s),
              ),
            ],
          ),
          if (semesters.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppTokens.space2),
              child: Text(
                '暂无学位课成绩记录',
                style: AppText.footnote.copyWith(color: tokens.labelTertiary),
              ),
            ),
          for (final s in semesters)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  // 两行布局：学期名在上、学分/门数在下，右侧只留 GPA，
                  // 避免窄屏下「学分 · 门数」被截断。
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.key,
                          style: AppText.footnote.copyWith(
                            color: tokens.labelSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${fmt(s.credits, 1)} 学分 · ${s.count} 门',
                          style: AppText.caption.copyWith(
                            color: tokens.labelTertiary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppTokens.space2),
                  Text(
                    fmt(s.gpa, 2),
                    style: AppText.numeric.copyWith(
                      color: tokens.labelPrimary,
                      fontSize: 17,
                    ),
                  ),
                ],
              ),
            ),
          if (spots.isNotEmpty) ...[
            const SizedBox(height: AppTokens.space4),
            SizedBox(
              height: 140,
              child: LineChart(
                LineChartData(
                  minY: 0,
                  maxY: 5,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 1,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: tokens.separator,
                      strokeWidth: 0.5,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(),
                    rightTitles: const AxisTitles(),
                    bottomTitles: const AxisTitles(),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 22,
                        interval: 1,
                        getTitlesWidget: (value, _) => Text(
                          value.toInt().toString(),
                          style: AppText.caption.copyWith(
                            color: tokens.labelTertiary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  extraLinesData: targetGpa == null
                      ? const ExtraLinesData()
                      : ExtraLinesData(
                          horizontalLines: [
                            HorizontalLine(
                              y: targetGpa,
                              color: tokens.danger,
                              strokeWidth: 1,
                              dashArray: [5, 4],
                            ),
                          ],
                        ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: false,
                      color: tokens.accent,
                      barWidth: 2.5,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, _, _, _) =>
                            FlDotCirclePainter(
                          radius: 3.5,
                          color: tokens.cardBackground,
                          strokeWidth: 2.5,
                          strokeColor: tokens.accent,
                        ),
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: tokens.accent.withAlpha(20),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (targetGpa != null)
              Padding(
                padding: const EdgeInsets.only(top: AppTokens.space2),
                child: Row(
                  children: [
                    Container(width: 14, height: 2, color: tokens.danger),
                    const SizedBox(width: AppTokens.space2),
                    Text(
                      '目标 ${targetGpa.toStringAsFixed(2)}'
                      '${scopeAll ? '' : '（学位课）'}',
                      style: AppText.caption.copyWith(
                        color: tokens.labelSecondary,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// 分数分布区：五档柱状图，支持全部课程/学位课范围切换。
class DistributionSection extends StatefulWidget {
  const DistributionSection({super.key, required this.stats});

  final StatsResult stats;

  @override
  State<DistributionSection> createState() => _DistributionSectionState();
}

class _DistributionSectionState extends State<DistributionSection> {
  TargetScope _scope = TargetScope.all;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final scopeAll = _scope == TargetScope.all;
    final dist = scopeAll
        ? widget.stats.overall.distribution
        : widget.stats.degree.distribution;
    final maxCount = dist.fold<int>(0, (a, b) => a > b ? a : b);

    return AppGlassGroupedCard(
      title: '成绩分布',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: _ScopeToggle(
              scope: _scope,
              onChanged: (s) => setState(() => _scope = s),
            ),
          ),
          SizedBox(
            height: 150,
            child: BarChart(
              BarChartData(
                maxY: (maxCount == 0 ? 1 : maxCount).toDouble(),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barTouchData: BarTouchData(enabled: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(),
                  rightTitles: const AxisTitles(),
                  leftTitles: const AxisTitles(),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      getTitlesWidget: (value, _) {
                        final i = value.toInt();
                        if (i < 0 || i >= distributionLabels.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            distributionLabels[i],
                            style: AppText.caption.copyWith(
                              color: tokens.labelSecondary,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: [
                  for (var i = 0; i < dist.length; i++)
                    BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: dist[i].toDouble(),
                          // 最后一档（<60）用危险色，其余强调色。
                          color: distributionLabels[i] == '<60'
                              ? tokens.danger
                              : tokens.accent,
                          width: 26,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(5),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
