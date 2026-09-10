import 'package:flutter/cupertino.dart';

import 'package:zfjw_toolkit/core/stats/result_types.dart';
import 'package:zfjw_toolkit/ui/kit/kit.dart';

/// 格式化辅助：null 安全的小数位数显示。
String fmt(double? v, int digits) => v == null ? '—' : v.toStringAsFixed(digits);

/// 目标差距文本：+0.12（已达标） / -0.34。
String diffText(double? gpa, double target) {
  if (gpa == null) return '—';
  final diff = gpa - target;
  final sign = diff >= 0 ? '+' : '';
  return '$sign${diff.toStringAsFixed(2)}${diff >= 0 ? '（已达标）' : ''}';
}

/// 统计总览卡：GPA 大字 + 各项指标行。
///
/// 玻璃卡 + 超大数值锚点，对齐 iOS 26 玻璃卡片的层次感。
class OverviewCard extends StatelessWidget {
  const OverviewCard({
    super.key,
    required this.stats,
    this.targetGpaAll,
    this.targetGpaDegree,
  });

  final StatsResult stats;

  /// 目标 GPA（全部课程，可选，展示差距）。
  final double? targetGpaAll;

  /// 目标 GPA（学位课，可选，展示差距）。
  final double? targetGpaDegree;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final o = stats.overall;
    final d = stats.degree;

    return AppGlassCard(
      glass: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                fmt(o.gpa, 2),
                style: AppText.display.copyWith(color: tokens.accent),
              ),
              const SizedBox(width: AppTokens.space2),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '总 GPA',
                  style: AppText.subhead.copyWith(color: tokens.labelSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.space4),
          AppDivider(),
          const SizedBox(height: AppTokens.space3),
          AppStatRow(label: '学位 GPA', value: fmt(d.gpa, 2), emphasize: true),
          if (targetGpaAll != null)
            AppStatRow(
              label: '总 GPA 差距',
              value: diffText(o.gpa, targetGpaAll!),
              valueColor: _diffColor(context, o.gpa, targetGpaAll!),
            ),
          if (targetGpaDegree != null)
            AppStatRow(
              label: '学位 GPA 差距',
              value: diffText(d.gpa, targetGpaDegree!),
              valueColor: _diffColor(context, d.gpa, targetGpaDegree!),
            ),
          AppStatRow(
            label: '加权平均分',
            value: fmt(o.weightedAvg, 1),
            emphasize: true,
          ),
          AppStatRow(label: '算术平均分', value: fmt(o.arithAvg, 1)),
          AppStatRow(
            label: '学分（已获 / 已修）',
            value: '${fmt(o.earnedCredits, 1)} / ${fmt(o.totalCredits, 1)}',
          ),
          AppStatRow(
            label: '学位学分（已获 / 已修）',
            value: '${fmt(d.earnedCredits, 1)} / ${fmt(d.totalCredits, 1)}',
          ),
          AppStatRow(label: '课程门数', value: '${o.count}（学位 ${d.count}）'),
          AppStatRow(
            label: '不及格',
            value: o.nonNumeric > 0
                ? '${o.failCount} 门；非百分制 ${o.nonNumeric} 门'
                : '${o.failCount} 门',
            valueColor: o.failCount > 0 ? tokens.danger : null,
          ),
          if (stats.exempt.count > 0)
            AppStatRow(
              label: '免修',
              value:
                  '${stats.exempt.count} 门（${fmt(stats.exempt.credits, 1)} 学分）',
              valueColor: tokens.labelSecondary,
            ),
          if (o.maxScore != null)
            AppStatRow(
              label: '最高分${o.maxCourse == null ? '' : '（${o.maxCourse}）'}',
              value: fmt(o.maxScore, 0),
            ),
          if (o.minScore != null)
            AppStatRow(
              label: '最低分${o.minCourse == null ? '' : '（${o.minCourse}）'}',
              value: fmt(o.minScore, 0),
            ),
        ],
      ),
    );
  }

  Color? _diffColor(BuildContext context, double? gpa, double target) {
    if (gpa == null) return null;
    final tokens = AppTokens.of(context);
    return gpa - target >= 0 ? tokens.success : tokens.danger;
  }
}

/// 警告区：挂科（红）+ 疑似误输入（橙）。
class WarningsSection extends StatelessWidget {
  const WarningsSection({super.key, required this.stats});

  final StatsResult stats;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);

    final failingRows = [
      for (final f in stats.failing)
        _WarningRow(
          color: tokens.danger,
          title: f.name ?? '未知课程',
          detail: [
            if (f.score == null) '无有效分数' else '${fmt(f.score, 0)} 分',
            if (f.credit != null) '${fmt(f.credit, 1)} 学分',
            f.semester,
          ].join('　'),
          tag: '挂科',
        ),
    ];

    final suspiciousRows = [
      for (final s in stats.suspicious)
        _WarningRow(
          color: tokens.warning,
          title: s.name ?? '未知课程',
          detail: '${fmt(s.score, 0)} 分　${s.semester}',
          tag: '疑似误输入',
        ),
    ];

    if (failingRows.isEmpty && suspiciousRows.isEmpty) {
      return const SizedBox.shrink();
    }

    final total = failingRows.length + suspiciousRows.length;

    return AppGlassGroupedCard(
      title: '警告',
      footer: '疑似误输入指百分制低于 10 分的记录，已按校规计 0 绩点。',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppCardTitle('需要关注 $total 项'),
          ...failingRows,
          if (failingRows.isNotEmpty && suspiciousRows.isNotEmpty)
            const SizedBox(height: AppTokens.space2),
          ...suspiciousRows,
        ],
      ),
    );
  }
}

class _WarningRow extends StatelessWidget {
  const _WarningRow({
    required this.color,
    required this.title,
    required this.detail,
    required this.tag,
  });

  final Color color;
  final String title;
  final String detail;
  final String tag;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTokens.space3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 3,
            height: 34,
            margin: const EdgeInsets.only(top: 1, right: AppTokens.space3),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(1.5),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: AppText.subhead.copyWith(
                          color: tokens.labelPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppTokens.space2),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: color.withAlpha(30),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        tag,
                        style: AppText.caption.copyWith(
                          color: color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: AppText.caption.copyWith(
                    color: tokens.labelSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
