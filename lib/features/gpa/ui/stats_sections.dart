import 'package:flutter/material.dart';

import 'package:zfjw_toolkit/core/stats/result_types.dart';
import 'package:zfjw_toolkit/ui/glass/glass.dart';

/// 格式化辅助：null 安全的小数位数显示。
String fmt(double? v, int digits) => v == null ? '—' : v.toStringAsFixed(digits);

/// 标签-值行（对齐油猴 row2）。
Widget statRow(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13)),
          Text(value, style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            fontFeatures: [],
          )),
        ],
      ),
    );

/// 目标差距文本：+0.12（已达标） / -0.34。
String _diffText(double? gpa, double target) {
  if (gpa == null) return '—';
  final diff = gpa - target;
  final sign = diff >= 0 ? '+' : '';
  return '$sign${diff.toStringAsFixed(2)}${diff >= 0 ? '（已达标）' : ''}';
}

/// 统计总览卡：GPA 大字 + 各项指标行。
class OverviewCard extends StatelessWidget {
  const OverviewCard({super.key, required this.stats, this.targetGpa});

  final StatsResult stats;

  /// 目标 GPA（可选，展示差距）。
  final double? targetGpa;

  @override
  Widget build(BuildContext context) {
    final o = stats.overall;
    final d = stats.degree;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            fmt(o.gpa, 2),
            style: TextStyle(
              fontSize: 42,
              fontWeight: FontWeight.w800,
              color: Theme.of(context).colorScheme.primary,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          statRow('学位 GPA', fmt(d.gpa, 2)),
          if (targetGpa != null) ...[
            statRow(
              '总 GPA 差距',
              _diffText(o.gpa, targetGpa!),
            ),
            statRow(
              '学位 GPA 差距',
              _diffText(d.gpa, targetGpa!),
            ),
          ],
          statRow(
            '加权平均分',
            '${fmt(o.weightedAvg, 1)}（算术 ${fmt(o.arithAvg, 1)}）',
          ),
          statRow('学分（已获/已修）', '${fmt(o.earnedCredits, 1)} / ${fmt(o.totalCredits, 1)}'),
          statRow('学位学分（已获/已修）', '${fmt(d.earnedCredits, 1)} / ${fmt(d.totalCredits, 1)}'),
          statRow('课程门数', '${o.count}（学位 ${d.count}）'),
          statRow(
            '不及格',
            '${o.failCount} 门${o.nonNumeric > 0 ? '；非百分制 ${o.nonNumeric} 门' : ''}',
          ),
          if (stats.exempt.count > 0)
            statRow(
              '免修',
              '${stats.exempt.count} 门（${fmt(stats.exempt.credits, 1)} 学分，不计入统计）',
            ),
          if (o.maxScore != null) statRow('最高分', '${fmt(o.maxScore, 0)} ${o.maxCourse ?? ''}'),
          if (o.minScore != null) statRow('最低分', '${fmt(o.minScore, 0)} ${o.minCourse ?? ''}'),
        ],
      ),
    );
  }
}

/// 警告区：挂科（红色左边条）+ 疑似误输入（黄色左边条）。
class WarningsSection extends StatelessWidget {
  const WarningsSection({super.key, required this.stats});

  final StatsResult stats;

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];
    for (final f in stats.failing) {
      items.add(_WarningRow(
        color: const Color(0xFFFF4D4D),
        text: '挂科：${f.name ?? '?'}　'
            '${f.score == null ? '无有效分数' : '${fmt(f.score, 0)} 分'}　'
            '${fmt(f.credit, 1)} 学分　${f.semester}',
      ));
    }
    for (final s in stats.suspicious) {
      items.add(_WarningRow(
        color: const Color(0xFFFFD02F),
        text: '疑似误输入：${s.name ?? '?'}　${fmt(s.score, 0)} 分'
            '（<10 分，已按校规计 0 绩点）　${s.semester}',
      ));
    }
    if (items.isEmpty) return const SizedBox.shrink();
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '警告（${items.length}）',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          ...items,
        ],
      ),
    );
  }
}

class _WarningRow extends StatelessWidget {
  const _WarningRow({required this.color, required this.text});

  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: color, width: 4)),
          color: color.withAlpha(20),
        ),
        child: Text(text, style: const TextStyle(fontSize: 12)),
      );
}
