import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'package:zfjw_toolkit/core/stats/result_types.dart';
import 'package:zfjw_toolkit/ui/glass/glass.dart';

import 'stats_sections.dart' show fmt;

/// 学期区：每学期一行统计 + fl_chart GPA 趋势折线（含目标虚线）。
class SemestersSection extends StatelessWidget {
  const SemestersSection({super.key, required this.semesters, this.targetGpa});

  final List<SemesterStat> semesters;

  /// 目标 GPA（可选，趋势线叠加虚线）。
  final double? targetGpa;

  @override
  Widget build(BuildContext context) {
    if (semesters.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '各学期（${semesters.length} 个）',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          for (final s in semesters)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(s.key, style: const TextStyle(fontSize: 12)),
                  ),
                  Text(
                    'GPA ${fmt(s.gpa, 2)} · ${fmt(s.credits, 1)} 学分 · ${s.count} 门',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          SizedBox(
            height: 140,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: 5,
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: const FlTitlesData(show: false),
                extraLinesData: targetGpa == null
                    ? const ExtraLinesData()
                    : ExtraLinesData(
                        horizontalLines: [
                          HorizontalLine(
                            y: targetGpa!,
                            color: scheme.error,
                            strokeWidth: 1.5,
                            dashArray: [6, 4],
                          ),
                        ],
                      ),
                lineBarsData: [
                  LineChartBarData(
                    spots: [
                      for (var i = 0; i < semesters.length; i++)
                        if (semesters[i].gpa != null)
                          FlSpot(i.toDouble(), semesters[i].gpa!),
                    ],
                    isCurved: false,
                    color: scheme.primary,
                    barWidth: 2.5,
                    dotData: const FlDotData(show: true),
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

/// 分数分布区：五档柱状图。
class DistributionSection extends StatelessWidget {
  const DistributionSection({super.key, required this.overall});

  final AggregateResult overall;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final maxCount = overall.distribution.fold<int>(0, (a, b) => a > b ? a : b);
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '分数分布',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 160,
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
                      getTitlesWidget: (value, _) {
                        final i = value.toInt();
                        if (i < 0 || i >= distributionLabels.length) {
                          return const SizedBox.shrink();
                        }
                        return Text(
                          distributionLabels[i],
                          style: const TextStyle(fontSize: 10),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: [
                  for (var i = 0; i < overall.distribution.length; i++)
                    BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: overall.distribution[i].toDouble(),
                          color: scheme.primary,
                          width: 24,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
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
