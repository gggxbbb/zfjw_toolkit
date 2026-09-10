import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'package:zfjw_toolkit/core/stats/result_types.dart';
import 'package:zfjw_toolkit/ui/kit/kit.dart';

import 'stats_sections.dart' show fmt;

/// 学期区：每学期一行统计 + GPA 趋势折线（含目标虚线）。
class SemestersSection extends StatelessWidget {
  const SemestersSection({super.key, required this.semesters, this.targetGpa});

  final List<SemesterStat> semesters;

  /// 目标 GPA（可选，趋势线叠加虚线）。
  final double? targetGpa;

  @override
  Widget build(BuildContext context) {
    if (semesters.isEmpty) return const SizedBox.shrink();
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
          AppCardTitle('各学期（${semesters.length} 个）'),
          for (final s in semesters)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      s.key,
                      style: AppText.footnote.copyWith(
                        color: tokens.labelSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AppTokens.space2),
                  Text(
                    fmt(s.gpa, 2),
                    style: AppText.numeric.copyWith(color: tokens.labelPrimary),
                  ),
                  const SizedBox(width: AppTokens.space3),
                  SizedBox(
                    width: 74,
                    child: Text(
                      '${fmt(s.credits, 1)} 学分 · ${s.count} 门',
                      style: AppText.caption.copyWith(
                        color: tokens.labelTertiary,
                      ),
                      textAlign: TextAlign.right,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
                              y: targetGpa!,
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
                        getDotPainter: (spot, _, __, ___) =>
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
                      '目标 ${targetGpa!.toStringAsFixed(2)}',
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

/// 分数分布区：五档柱状图。
class DistributionSection extends StatelessWidget {
  const DistributionSection({super.key, required this.overall});

  final AggregateResult overall;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final dist = overall.distribution;
    final maxCount = dist.fold<int>(0, (a, b) => a > b ? a : b);

    return AppGlassGroupedCard(
      title: '成绩分布',
      child: SizedBox(
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
    );
  }
}
